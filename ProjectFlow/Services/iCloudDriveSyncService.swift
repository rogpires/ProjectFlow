import Foundation
import Observation
import SwiftData
import AppKit

enum SyncStatus: Equatable {
    case disabled
    case idle
    case syncing
    case synced(Date)
    case error(String)
}

@MainActor
@Observable
final class iCloudDriveSyncService {
    private weak var appState: AppState?
    private var pollTimer: Timer?
    private var pushDebounceTask: Task<Void, Never>?
    private var localRevision = 0
    private var lastImportedAt: Date?
    private var tombstones: Set<String> = []

    var status: SyncStatus = .disabled
    var remoteActiveTimer: ActiveTimerDTO?

    private let dataFileName = "data.json"
    private let tombstonesKey = "ProjectFlow.syncTombstones"
    private let revisionKey = "ProjectFlow.localRevision"

    func bind(to appState: AppState) {
        self.appState = appState
        tombstones = Set(UserDefaults.standard.stringArray(forKey: tombstonesKey) ?? [])
        localRevision = UserDefaults.standard.integer(forKey: revisionKey)
        status = SyncBookmarkStore.isConfigured ? .idle : .disabled
    }

    var isConfigured: Bool { SyncBookmarkStore.isConfigured }

    var folderPath: String? { SyncBookmarkStore.folderDisplayName }

    func configureFolder(_ url: URL) {
        SyncBookmarkStore.saveBookmark(for: url)
        status = .idle
        Task { await syncNow() }
        startPolling()
    }

    func clearFolder() {
        stopPolling()
        SyncBookmarkStore.clear()
        status = .disabled
    }

    func startPolling() {
        stopPolling()
        guard SyncBookmarkStore.isConfigured else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncNow()
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func requestSync() {
        guard SyncBookmarkStore.isConfigured else { return }
        pushDebounceTask?.cancel()
        pushDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            await syncNow()
        }
    }

    func registerDeletion(syncId: String) {
        tombstones.insert(syncId)
        UserDefaults.standard.set(Array(tombstones), forKey: tombstonesKey)
        requestSync()
    }

    func canStartTimer(projectSyncId: String, taskSyncId: String) -> (allowed: Bool, message: String?) {
        guard let remote = remoteActiveTimer else { return (true, nil) }
        if remote.deviceId == SyncDevice.id { return (true, nil) }
        return (false, "Timer ativo em outro Mac desde \(AppFormatters.dateTime.string(from: remote.startedAt)).")
    }

    func syncNow() async {
        guard SyncBookmarkStore.isConfigured, let context = appState?.modelContext else { return }
        status = .syncing
        ensureSyncIds(in: context)

        do {
            if let remote = try readRemotePackage() {
                remoteActiveTimer = remote.activeTimer
                if shouldImport(remote) {
                    try merge(remote: remote, into: context)
                    lastImportedAt = remote.exportedAt
                }
            }
            try pushLocalChanges(context: context)
            status = .synced(Date())
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    private func pushLocalChanges(context: ModelContext) throws {
        guard let folder = SyncBookmarkStore.resolveFolderURL() else { return }
        guard folder.startAccessingSecurityScopedResource() else { throw SyncError.accessDenied }
        defer { folder.stopAccessingSecurityScopedResource() }

        localRevision += 1
        UserDefaults.standard.set(localRevision, forKey: revisionKey)

        let package = buildPackage(from: context)
        let fileURL = folder.appendingPathComponent(dataFileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(package)

        var coordinatorError: NSError?
        var innerError: Error?
        NSFileCoordinator().coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinatorError) { url in
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                innerError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let innerError { throw innerError }
    }

    private func buildPackage(from context: ModelContext) -> SyncPackage {
        let timer = appState?.timerService
        var activeTimer: ActiveTimerDTO?
        if let timer, timer.isActive,
           let project = timer.currentProject,
           let task = timer.currentTask {
            _ = SyncIdentity.ensure(&project.syncId)
            _ = SyncIdentity.ensure(&task.syncId)
            activeTimer = ActiveTimerDTO(
                deviceId: SyncDevice.id,
                projectSyncId: project.syncId,
                taskSyncId: task.syncId,
                startedAt: timer.sessionStartDate ?? Date(),
                state: timer.state == .running ? "running" : "paused"
            )
        }

        let projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        let entries = (try? context.fetch(FetchDescriptor<TimeEntry>())) ?? []
        let tags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        let logs = (try? context.fetch(FetchDescriptor<ActivityLog>())) ?? []
        let goals = (try? context.fetch(FetchDescriptor<Goal>())) ?? []
        let pomodoros = (try? context.fetch(FetchDescriptor<PomodoroSession>())) ?? []

        return SyncPackage(
            revision: localRevision,
            exportedAt: Date(),
            deviceId: SyncDevice.id,
            deletedSyncIds: Array(tombstones),
            activeTimer: activeTimer,
            projects: projects.map { projectDTO($0) },
            tasks: tasks.compactMap { taskDTO($0) },
            timeEntries: entries.compactMap { timeEntryDTO($0) },
            tags: tags.map { tagDTO($0) },
            activityLogs: logs.map { activityLogDTO($0) },
            goals: goals.map { goalDTO($0) },
            pomodoroSessions: pomodoros.compactMap { pomodoroDTO($0) }
        )
    }

    private func shouldImport(_ remote: SyncPackage) -> Bool {
        if remote.deviceId == SyncDevice.id { return false }
        if let lastImportedAt, remote.exportedAt <= lastImportedAt { return false }
        return true
    }

    private func readRemotePackage() throws -> SyncPackage? {
        guard let folder = SyncBookmarkStore.resolveFolderURL() else { return nil }
        guard folder.startAccessingSecurityScopedResource() else { throw SyncError.accessDenied }
        defer { folder.stopAccessingSecurityScopedResource() }

        let fileURL = folder.appendingPathComponent(dataFileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        var coordinatorError: NSError?
        var data: Data?
        NSFileCoordinator().coordinate(readingItemAt: fileURL, options: [], error: &coordinatorError) { url in
            data = try? Data(contentsOf: url)
        }
        if let coordinatorError { throw coordinatorError }
        guard let data else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SyncPackage.self, from: data)
    }

    private func merge(remote: SyncPackage, into context: ModelContext) throws {
        applyDeletions(remote.deletedSyncIds, context: context)

        var projectMap: [String: Project] = [:]
        for dto in remote.projects {
            projectMap[dto.syncId] = upsertProject(dto, context: context)
        }

        var tagMap: [String: Tag] = [:]
        for dto in remote.tags {
            tagMap[dto.syncId] = upsertTag(dto, context: context)
        }

        var taskMap: [String: TaskItem] = [:]
        for dto in remote.tasks {
            if let task = upsertTask(dto, projectMap: projectMap, context: context) {
                taskMap[dto.syncId] = task
            }
        }

        for dto in remote.timeEntries {
            upsertTimeEntry(dto, projectMap: projectMap, taskMap: taskMap, tagMap: tagMap, context: context)
        }
        for dto in remote.activityLogs {
            upsertActivityLog(dto, context: context)
        }
        for dto in remote.goals {
            upsertGoal(dto, context: context)
        }
        for dto in remote.pomodoroSessions {
            upsertPomodoro(dto, projectMap: projectMap, taskMap: taskMap, context: context)
        }

        try context.save()
    }

    private func applyDeletions(_ ids: [String], context: ModelContext) {
        for syncId in ids {
            deleteBySyncId(syncId, context: context)
        }
    }

    private func deleteBySyncId(_ syncId: String, context: ModelContext) {
        if let p = fetchProject(syncId, context: context) { context.delete(p); return }
        if let t = fetchTask(syncId, context: context) { context.delete(t); return }
        if let e = fetchTimeEntry(syncId, context: context) { context.delete(e); return }
        if let tag = fetchTag(syncId, context: context) { context.delete(tag); return }
        if let g = fetchGoal(syncId, context: context) { context.delete(g); return }
        if let log = fetchActivityLog(syncId, context: context) { context.delete(log); return }
        if let p = fetchPomodoro(syncId, context: context) { context.delete(p) }
    }

    private func upsertProject(_ dto: ProjectDTO, context: ModelContext) -> Project {
        let existing = fetchProject(dto.syncId, context: context)
        if let existing, existing.updatedAt >= dto.updatedAt { return existing }
        let project = existing ?? Project(name: dto.name)
        if existing == nil { context.insert(project) }
        project.syncId = dto.syncId
        project.updatedAt = dto.updatedAt
        project.name = dto.name
        project.projectDescription = dto.projectDescription
        project.categoryRaw = dto.categoryRaw
        project.statusRaw = dto.statusRaw
        project.createdAt = dto.createdAt
        project.completedAt = dto.completedAt
        project.colorHex = dto.colorHex
        project.iconName = dto.iconName
        project.hourlyRate = dto.hourlyRate
        project.estimatedROI = dto.estimatedROI
        return project
    }

    private func upsertTag(_ dto: TagDTO, context: ModelContext) -> Tag {
        let existing = fetchTag(dto.syncId, context: context)
        if let existing, existing.updatedAt >= dto.updatedAt { return existing }
        let tag = existing ?? Tag(name: dto.name)
        if existing == nil { context.insert(tag) }
        tag.syncId = dto.syncId
        tag.updatedAt = dto.updatedAt
        tag.name = dto.name
        tag.colorHex = dto.colorHex
        tag.createdAt = dto.createdAt
        return tag
    }

    private func upsertTask(_ dto: TaskDTO, projectMap: [String: Project], context: ModelContext) -> TaskItem? {
        guard let project = projectMap[dto.projectSyncId] else { return nil }
        let existing = fetchTask(dto.syncId, context: context)
        if let existing, existing.updatedAt >= dto.updatedAt { return existing }
        let task = existing ?? TaskItem(name: dto.name, project: project)
        if existing == nil { context.insert(task) }
        task.syncId = dto.syncId
        task.updatedAt = dto.updatedAt
        task.project = project
        task.name = dto.name
        task.taskDescription = dto.taskDescription
        task.priorityRaw = dto.priorityRaw
        task.statusRaw = dto.statusRaw
        task.estimatedSeconds = dto.estimatedSeconds
        task.actualSeconds = dto.actualSeconds
        task.createdAt = dto.createdAt
        task.completedAt = dto.completedAt
        return task
    }

    private func upsertTimeEntry(
        _ dto: TimeEntryDTO,
        projectMap: [String: Project],
        taskMap: [String: TaskItem],
        tagMap: [String: Tag],
        context: ModelContext
    ) {
        guard let project = projectMap[dto.projectSyncId],
              let task = taskMap[dto.taskSyncId] else { return }
        let existing = fetchTimeEntry(dto.syncId, context: context)
        if let existing, existing.updatedAt >= dto.updatedAt { return }
        let entry = existing ?? TimeEntry(startDate: dto.startDate, project: project, task: task)
        if existing == nil { context.insert(entry) }
        entry.syncId = dto.syncId
        entry.updatedAt = dto.updatedAt
        entry.project = project
        entry.task = task
        entry.startDate = dto.startDate
        entry.endDate = dto.endDate
        entry.notes = dto.notes
        entry.isRunning = dto.isRunning
        entry.tags = dto.tagSyncIds.compactMap { tagMap[$0] }
    }

    private func upsertActivityLog(_ dto: ActivityLogDTO, context: ModelContext) {
        let existing = fetchActivityLog(dto.syncId, context: context)
        if let existing, existing.updatedAt >= dto.updatedAt { return }
        let log = existing ?? ActivityLog(action: .timerStarted)
        if existing == nil { context.insert(log) }
        log.syncId = dto.syncId
        log.updatedAt = dto.updatedAt
        log.timestamp = dto.timestamp
        log.actionRaw = dto.actionRaw
        log.details = dto.details
        log.projectName = dto.projectName
        log.taskName = dto.taskName
    }

    private func upsertGoal(_ dto: GoalDTO, context: ModelContext) {
        let existing = fetchGoal(dto.syncId, context: context)
        if let existing, existing.updatedAt >= dto.updatedAt { return }
        let goal = existing ?? Goal(title: dto.title, targetHours: dto.targetHours, period: .daily)
        if existing == nil { context.insert(goal) }
        goal.syncId = dto.syncId
        goal.updatedAt = dto.updatedAt
        goal.title = dto.title
        goal.targetHours = dto.targetHours
        goal.periodRaw = dto.periodRaw
        goal.createdAt = dto.createdAt
        goal.isActive = dto.isActive
    }

    private func upsertPomodoro(
        _ dto: PomodoroSessionDTO,
        projectMap: [String: Project],
        taskMap: [String: TaskItem],
        context: ModelContext
    ) {
        let existing = fetchPomodoro(dto.syncId, context: context)
        if let existing, existing.updatedAt >= dto.updatedAt { return }
        let session = existing ?? PomodoroSession()
        if existing == nil { context.insert(session) }
        session.syncId = dto.syncId
        session.updatedAt = dto.updatedAt
        session.startDate = dto.startDate
        session.endDate = dto.endDate
        session.workMinutes = dto.workMinutes
        session.breakMinutes = dto.breakMinutes
        session.completedCycles = dto.completedCycles
        session.isWorkPhase = dto.isWorkPhase
        session.modeRaw = dto.modeRaw
        if let pid = dto.projectSyncId { session.project = projectMap[pid] }
        if let tid = dto.taskSyncId { session.task = taskMap[tid] }
    }

    private func fetchProject(_ syncId: String, context: ModelContext) -> Project? {
        var d = FetchDescriptor<Project>(predicate: #Predicate { $0.syncId == syncId })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    private func fetchTask(_ syncId: String, context: ModelContext) -> TaskItem? {
        var d = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.syncId == syncId })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    private func fetchTimeEntry(_ syncId: String, context: ModelContext) -> TimeEntry? {
        var d = FetchDescriptor<TimeEntry>(predicate: #Predicate { $0.syncId == syncId })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    private func fetchTag(_ syncId: String, context: ModelContext) -> Tag? {
        var d = FetchDescriptor<Tag>(predicate: #Predicate { $0.syncId == syncId })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    private func fetchGoal(_ syncId: String, context: ModelContext) -> Goal? {
        var d = FetchDescriptor<Goal>(predicate: #Predicate { $0.syncId == syncId })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    private func fetchActivityLog(_ syncId: String, context: ModelContext) -> ActivityLog? {
        var d = FetchDescriptor<ActivityLog>(predicate: #Predicate { $0.syncId == syncId })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    private func fetchPomodoro(_ syncId: String, context: ModelContext) -> PomodoroSession? {
        var d = FetchDescriptor<PomodoroSession>(predicate: #Predicate { $0.syncId == syncId })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    private func ensureSyncIds(in context: ModelContext) {
        assignMissingSyncIds((try? context.fetch(FetchDescriptor<Project>())) ?? [])
        assignMissingSyncIds((try? context.fetch(FetchDescriptor<TaskItem>())) ?? [])
        assignMissingSyncIds((try? context.fetch(FetchDescriptor<TimeEntry>())) ?? [])
        assignMissingSyncIds((try? context.fetch(FetchDescriptor<Tag>())) ?? [])
        assignMissingSyncIds((try? context.fetch(FetchDescriptor<ActivityLog>())) ?? [])
        assignMissingSyncIds((try? context.fetch(FetchDescriptor<Goal>())) ?? [])
        assignMissingSyncIds((try? context.fetch(FetchDescriptor<PomodoroSession>())) ?? [])
        try? context.save()
    }

    private func assignMissingSyncIds<T: PersistentModel>(_ items: [T]) {
        for item in items {
            if let project = item as? Project, project.syncId.isEmpty {
                project.syncId = UUID().uuidString
                project.updatedAt = Date()
            } else if let task = item as? TaskItem, task.syncId.isEmpty {
                task.syncId = UUID().uuidString
                task.updatedAt = Date()
            } else if let entry = item as? TimeEntry, entry.syncId.isEmpty {
                entry.syncId = UUID().uuidString
                entry.updatedAt = Date()
            } else if let tag = item as? Tag, tag.syncId.isEmpty {
                tag.syncId = UUID().uuidString
                tag.updatedAt = Date()
            } else if let log = item as? ActivityLog, log.syncId.isEmpty {
                log.syncId = UUID().uuidString
                log.updatedAt = Date()
            } else if let goal = item as? Goal, goal.syncId.isEmpty {
                goal.syncId = UUID().uuidString
                goal.updatedAt = Date()
            } else if let session = item as? PomodoroSession, session.syncId.isEmpty {
                session.syncId = UUID().uuidString
                session.updatedAt = Date()
            }
        }
    }

    private func projectDTO(_ project: Project) -> ProjectDTO {
        _ = SyncIdentity.ensure(&project.syncId)
        return ProjectDTO(
            syncId: project.syncId,
            updatedAt: project.updatedAt,
            name: project.name,
            projectDescription: project.projectDescription,
            categoryRaw: project.categoryRaw,
            statusRaw: project.statusRaw,
            createdAt: project.createdAt,
            completedAt: project.completedAt,
            colorHex: project.colorHex,
            iconName: project.iconName,
            hourlyRate: project.hourlyRate,
            estimatedROI: project.estimatedROI,
            tagSyncIds: project.tags.map { tag in
                SyncIdentity.ensure(&tag.syncId)
                return tag.syncId
            }
        )
    }

    private func taskDTO(_ task: TaskItem) -> TaskDTO? {
        guard let project = task.project else { return nil }
        _ = SyncIdentity.ensure(&task.syncId)
        _ = SyncIdentity.ensure(&project.syncId)
        return TaskDTO(
            syncId: task.syncId,
            updatedAt: task.updatedAt,
            projectSyncId: project.syncId,
            name: task.name,
            taskDescription: task.taskDescription,
            priorityRaw: task.priorityRaw,
            statusRaw: task.statusRaw,
            estimatedSeconds: task.estimatedSeconds,
            actualSeconds: task.actualSeconds,
            createdAt: task.createdAt,
            completedAt: task.completedAt
        )
    }

    private func timeEntryDTO(_ entry: TimeEntry) -> TimeEntryDTO? {
        guard let project = entry.project, let task = entry.task else { return nil }
        _ = SyncIdentity.ensure(&entry.syncId)
        _ = SyncIdentity.ensure(&project.syncId)
        _ = SyncIdentity.ensure(&task.syncId)
        return TimeEntryDTO(
            syncId: entry.syncId,
            updatedAt: entry.updatedAt,
            projectSyncId: project.syncId,
            taskSyncId: task.syncId,
            startDate: entry.startDate,
            endDate: entry.endDate,
            notes: entry.notes,
            isRunning: entry.isRunning,
            tagSyncIds: entry.tags.map { tag in
                SyncIdentity.ensure(&tag.syncId)
                return tag.syncId
            }
        )
    }

    private func tagDTO(_ tag: Tag) -> TagDTO {
        _ = SyncIdentity.ensure(&tag.syncId)
        return TagDTO(
            syncId: tag.syncId,
            updatedAt: tag.updatedAt,
            name: tag.name,
            colorHex: tag.colorHex,
            createdAt: tag.createdAt
        )
    }

    private func activityLogDTO(_ log: ActivityLog) -> ActivityLogDTO {
        _ = SyncIdentity.ensure(&log.syncId)
        return ActivityLogDTO(
            syncId: log.syncId,
            updatedAt: log.updatedAt,
            timestamp: log.timestamp,
            actionRaw: log.actionRaw,
            details: log.details,
            projectName: log.projectName,
            taskName: log.taskName
        )
    }

    private func goalDTO(_ goal: Goal) -> GoalDTO {
        _ = SyncIdentity.ensure(&goal.syncId)
        return GoalDTO(
            syncId: goal.syncId,
            updatedAt: goal.updatedAt,
            title: goal.title,
            targetHours: goal.targetHours,
            periodRaw: goal.periodRaw,
            createdAt: goal.createdAt,
            isActive: goal.isActive
        )
    }

    private func pomodoroDTO(_ session: PomodoroSession) -> PomodoroSessionDTO {
        _ = SyncIdentity.ensure(&session.syncId)
        var projectSyncId: String?
        if let project = session.project {
            projectSyncId = SyncIdentity.ensure(&project.syncId)
        }
        var taskSyncId: String?
        if let task = session.task {
            taskSyncId = SyncIdentity.ensure(&task.syncId)
        }
        return PomodoroSessionDTO(
            syncId: session.syncId,
            updatedAt: session.updatedAt,
            startDate: session.startDate,
            endDate: session.endDate,
            workMinutes: session.workMinutes,
            breakMinutes: session.breakMinutes,
            completedCycles: session.completedCycles,
            isWorkPhase: session.isWorkPhase,
            modeRaw: session.modeRaw,
            projectSyncId: projectSyncId,
            taskSyncId: taskSyncId
        )
    }
}

enum SyncError: LocalizedError {
    case accessDenied
    case folderNotSelected

    var errorDescription: String? {
        switch self {
        case .accessDenied: "Sem permissão para acessar a pasta iCloud."
        case .folderNotSelected: "Selecione uma pasta no iCloud Drive."
        }
    }
}
