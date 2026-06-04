//
//  ProjectDetailView.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import SwiftUI
import SwiftData
import AppKit

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppState.self) private var appState
    @Bindable var project: Project
    @Query private var projectScopedTasks: [TaskItem]

    init(project: Project) {
        self.project = project
        let syncId = project.syncId
        _projectScopedTasks = Query(
            filter: #Predicate<TaskItem> { task in
                task.project?.syncId == syncId
            },
            sort: \TaskItem.createdAt,
            order: .reverse
        )
    }

    @State private var showingEdit = false
    @State private var showingNewTask = false
    @State private var taskEditContext: TaskEditSheetContext?
    @State private var showingDeleteConfirm = false
    @State private var taskSortOption: TaskSortOption = .priority
    @State private var contributionActivity: GitContributionActivity?
    @State private var isLoadingGit = false
    @State private var resolvedGitRoot: String?
    @State private var gitErrorMessage: String?
    @State private var gitParsedCommitLines = 0
    @State private var gitKrakenError: String?

    private var allProjectTasks: [TaskItem] {
        taskSortOption.sort(TimeEntryQueryHelper.uniqueByID(projectScopedTasks))
    }

    private var openProjectTasks: [TaskItem] {
        allProjectTasks.filter { $0.status != .completed }
    }

    private var completedProjectTasks: [TaskItem] {
        allProjectTasks.filter { $0.status == .completed }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if project.hasGitRepository {
                    gitSection
                }
                financialSummary
                tasksSection
            }
            .padding(24)
        }
        .navigationTitle(project.name)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showingEdit = true
                } label: {
                    Label("Editar", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Label("Excluir", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            ProjectFormView(project: project)
        }
        .onChange(of: showingEdit) { _, isShowing in
            if !isShowing {
                refreshGitInfo()
            }
        }
        .sheet(isPresented: $showingNewTask) {
            TaskFormView(project: project)
        }
        .sheet(item: $taskEditContext) { context in
            TaskFormView(project: context.project, task: context.task)
        }
        .confirmationDialog("Excluir projeto?", isPresented: $showingDeleteConfirm) {
            Button("Excluir", role: .destructive) {
                _ = SyncIdentity.ensure(&project.syncId)
                for task in project.tasks {
                    _ = SyncIdentity.ensure(&task.syncId)
                    appState.syncService.registerDeletion(syncId: task.syncId)
                }
                appState.syncService.registerDeletion(syncId: project.syncId)
                context.delete(project)
                try? context.save()
                appState.selectedProject = nil
                appState.notifyDataChanged()
            }
        } message: {
            Text("Esta ação não pode ser desfeita. Todas as tarefas e registros serão removidos.")
        }
        .onAppear { refreshGitInfo() }
        .onChange(of: project.gitRepositoryPath) { _, _ in refreshGitInfo() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, project.hasGitRepository {
                refreshGitInfo()
            }
        }
        .alert("GitKraken", isPresented: .init(
            get: { gitKrakenError != nil },
            set: { if !$0 { gitKrakenError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(gitKrakenError ?? "")
        }
    }

    private var gitSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Git", systemImage: "arrow.triangle.branch")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button {
                    refreshGitInfo()
                } label: {
                    Label("Atualizar", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingGit)
                if GitKrakenSettings.isEnabled {
                    Button {
                        openInGitKraken()
                    } label: {
                        Label("Abrir no GitKraken", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!GitKrakenService.isInstalled)
                }
            }

            if let gitErrorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(gitErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }

            if !project.gitRepositoryPath.isEmpty {
                Text(resolvedGitRoot ?? project.gitRepositoryPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
            }

            if let activity = contributionActivity, !activity.weeks.isEmpty {
                GitContributionHeatmapView(
                    activity: activity,
                    accentColor: Color(hex: project.colorHex)
                )
                if isLoadingGit {
                    ProgressView()
                        .controlSize(.small)
                }
            } else if isLoadingGit {
                ProgressView("Carregando atividade Git…")
                    .controlSize(.small)
            } else if contributionActivity != nil {
                if gitParsedCommitLines > 0 {
                    Text("O Git tem \(gitParsedCommitLines) commits, mas nenhum no último ano neste repositório.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Nenhum commit encontrado. Edite o projeto, escolha a pasta do repositório com **Escolher…** e toque em **Atualizar**.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ProgressView("Carregando atividade Git…")
                    .controlSize(.small)
            }
        }
        .padding(16)
        .background(.background.secondary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private func refreshGitInfo() {
        guard project.hasGitRepository else {
            contributionActivity = nil
            resolvedGitRoot = nil
            gitErrorMessage = nil
            gitParsedCommitLines = 0
            isLoadingGit = false
            return
        }
        let path = project.gitRepositoryPath
        let syncId = project.syncId
        _ = SyncIdentity.ensure(&project.syncId)
        isLoadingGit = true
        gitErrorMessage = nil

        Task {
            let result = await GitRepositoryHelper.loadRepository(
                storedPath: path,
                projectSyncId: syncId
            )

            await MainActor.run {
                resolvedGitRoot = result.root
                gitErrorMessage = result.errorMessage
                gitParsedCommitLines = result.parsedCommitLines
                contributionActivity = GitContributionActivity(countsByDay: result.counts)
                isLoadingGit = false
            }
        }
    }

    private func openInGitKraken() {
        let path = project.gitRepositoryPath
        let syncId = project.syncId
        Task {
            do {
                _ = SyncIdentity.ensure(&project.syncId)
                try await GitKrakenService.openRepository(at: path, projectSyncId: syncId)
            } catch {
                await MainActor.run {
                    gitKrakenError = error.localizedDescription
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: project.iconName)
                .font(.system(size: 40))
                .foregroundStyle(Color(hex: project.colorHex))
                .frame(width: 64, height: 64)
                .background(Color(hex: project.colorHex).opacity(0.15), in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 6) {
                Text(project.name)
                    .font(.title.bold())
                if !project.projectDescription.isEmpty {
                    Text(project.projectDescription)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label(project.category.rawValue, systemImage: project.category.icon)
                    Label(project.status.rawValue, systemImage: project.status.icon)
                    Text("Criado em \(AppFormatters.shortDate.string(from: project.createdAt))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var financialSummary: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "Valor investido",
                value: AppFormatters.formatCurrency(project.investedValue),
                subtitle: "\(AppFormatters.formatHours(project.totalSeconds)) trabalhadas",
                icon: "dollarsign.circle.fill",
                color: Color(hex: project.colorHex)
            )
            StatCard(
                title: "Valor estimado",
                value: AppFormatters.formatCurrency(project.estimatedValue),
                subtitle: "Baseado em estimativas",
                icon: "chart.bar.fill",
                color: .orange
            )
            StatCard(
                title: "Valor acumulado",
                value: AppFormatters.formatCurrency(project.accumulatedValue),
                subtitle: "R$ \(Int(project.hourlyRate))/h",
                icon: "banknote.fill",
                color: .green
            )
        }
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("Tarefas")
                    .font(.title2.bold())

                Spacer(minLength: 16)

                Picker("Ordenar", selection: $taskSortOption) {
                    ForEach(TaskSortOption.allCases) { option in
                        Label(option.rawValue, systemImage: option.icon).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()

                Button("Adicionar") {
                    showingNewTask = true
                }
                .buttonStyle(.borderedProminent)
            }

            if allProjectTasks.isEmpty {
                EmptyStateView(
                    icon: "checklist",
                    title: "Sem tarefas",
                    message: "Adicione tarefas para organizar o trabalho neste projeto."
                )
                .frame(height: 200)
            } else {
                if !openProjectTasks.isEmpty {
                    ForEach(openProjectTasks, id: \.persistentModelID) { task in
                        taskRow(task)
                    }
                }

                if !completedProjectTasks.isEmpty {
                    taskSectionDivider(title: "Concluídas", count: completedProjectTasks.count)
                    ForEach(completedProjectTasks, id: \.persistentModelID) { task in
                        taskRow(task)
                    }
                }
            }
        }
    }

    private func taskRow(_ task: TaskItem) -> some View {
        TaskRowView(task: task, project: project) {
            taskEditContext = TaskEditSheetContext(project: project, task: task)
        }
    }

    private func taskSectionDivider(title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text("(\(count))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)
        }
        .padding(.top, openProjectTasks.isEmpty ? 0 : 8)
        .foregroundStyle(.secondary)
    }
}

struct TaskRowView: View {
    @Environment(AppState.self) private var appState
    @Bindable var task: TaskItem
    let project: Project
    var onEdit: () -> Void

    private var isTrackingSameTask: Bool {
        let timer = appState.timerService
        return timer.isActive
            && timer.currentProject?.persistentModelID == project.persistentModelID
            && timer.currentTask?.persistentModelID == task.persistentModelID
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(task.priority.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.15), in: Capsule())
                    Text(task.status.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(AppFormatters.formatHours(task.totalWorkedSeconds))
                    .font(.subheadline.monospacedDigit())
                if task.estimatedSeconds > 0 {
                    Text("de \(AppFormatters.formatHours(task.estimatedSeconds))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                guard !isTrackingSameTask else { return }
                appState.timerService.start(project: project, task: task)
            } label: {
                Image(systemName: isTrackingSameTask ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.borderless)
            .help(isTrackingSameTask ? "Timer em andamento" : "Iniciar timer")
            .disabled(isTrackingSameTask)

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
    }
}
