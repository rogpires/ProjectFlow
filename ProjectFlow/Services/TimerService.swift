import Foundation
import Observation
import SwiftData

enum TimerState: Equatable {
    case idle
    case running
    case paused
}

@MainActor
@Observable
final class TimerService {
    private weak var appState: AppState?

    var state: TimerState = .idle
    var currentProject: Project?
    var currentTask: TaskItem?
    var elapsedSeconds: TimeInterval = 0
    var sessionStartDate: Date?

    private var tickTimer: Timer?
    private var pausedAccumulated: TimeInterval = 0
    private var pauseStartedAt: Date?

    var isActive: Bool { state == .running || state == .paused }

    var displayTime: String {
        AppFormatters.formatDuration(elapsedSeconds)
    }

    var statusIcon: String {
        switch state {
        case .idle: "circle"
        case .running: "circle.fill"
        case .paused: "pause.circle.fill"
        }
    }

    func bind(to appState: AppState) {
        self.appState = appState
    }

    func start(project: Project, task: TaskItem) {
        guard let context = appState?.modelContext else { return }

        _ = SyncIdentity.ensure(&project.syncId)
        _ = SyncIdentity.ensure(&task.syncId)
        let check = appState?.syncService.canStartTimer(
            projectSyncId: project.syncId,
            taskSyncId: task.syncId
        )
        if let check, !check.allowed { return }

        if state != .idle {
            let sameTask = currentProject?.persistentModelID == project.persistentModelID
                && currentTask?.persistentModelID == task.persistentModelID
            if sameTask { return }
            stop(save: true)
        }

        currentProject = project
        currentTask = task
        sessionStartDate = Date()
        elapsedSeconds = 0
        pausedAccumulated = 0
        pauseStartedAt = nil

        if task.status == .todo {
            task.status = .inProgress
        }
        if project.status == .planning {
            project.status = .inProgress
        }

        state = .running
        startTicking()
        appState?.activityLogger.log(
            action: .timerStarted,
            details: "Iniciou timer para \(task.name)",
            project: project,
            task: task,
            context: context
        )
        try? context.save()
        appState?.notifyDataChanged()
    }

    func pause() {
        guard state == .running, let context = appState?.modelContext else { return }
        state = .paused
        pauseStartedAt = Date()
        stopTicking()
        appState?.activityLogger.log(
            action: .timerPaused,
            project: currentProject,
            task: currentTask,
            context: context
        )
        try? context.save()
        appState?.notifyDataChanged()
    }

    func resume() {
        guard state == .paused, let context = appState?.modelContext else { return }
        if let pauseStartedAt {
            pausedAccumulated += Date().timeIntervalSince(pauseStartedAt)
        }
        self.pauseStartedAt = nil
        state = .running
        startTicking()
        appState?.activityLogger.log(
            action: .timerResumed,
            project: currentProject,
            task: currentTask,
            context: context
        )
        try? context.save()
        appState?.notifyDataChanged()
    }

    func stop(save: Bool = true) {
        guard let context = appState?.modelContext else { return }
        stopTicking()

        if save, state != .idle {
            persistSession(context: context)
        }

        resetSession()
        try? context.save()
        appState?.notifyDataChanged()
    }

    func switchProject(_ project: Project, task: TaskItem) {
        stop(save: true)
        start(project: project, task: task)
    }

    private func persistSession(context: ModelContext) {
        guard let sessionStartDate,
              let project = currentProject,
              let task = currentTask,
              elapsedSeconds >= 1,
              let logger = appState?.activityLogger else { return }

        let entry = TimeEntry(startDate: sessionStartDate, project: project, task: task)
        entry.endDate = sessionStartDate.addingTimeInterval(elapsedSeconds)
        entry.isRunning = false
        SyncIdentity.touch(&entry.updatedAt)
        context.insert(entry)
        task.refreshActualSeconds()

        logger.log(
            action: .timerStopped,
            details: "Sessão: \(AppFormatters.formatDuration(elapsedSeconds))",
            project: project,
            task: task,
            context: context
        )
    }

    private func resetSession() {
        state = .idle
        elapsedSeconds = 0
        pausedAccumulated = 0
        pauseStartedAt = nil
        sessionStartDate = nil
    }

    private func startTicking() {
        stopTicking()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsed()
            }
        }
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func updateElapsed() {
        guard let sessionStartDate, state == .running else { return }
        elapsedSeconds = Date().timeIntervalSince(sessionStartDate) - pausedAccumulated
    }
}
