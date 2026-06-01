//
//  ProjectDetailView.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Bindable var project: Project
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var allTasks: [TaskItem]

    @State private var showingEdit = false
    @State private var showingNewTask = false
    @State private var showingDeleteConfirm = false
    @State private var taskSortOption: TaskSortOption = .priority

    private var projectTasks: [TaskItem] {
        let tasks = TimeEntryQueryHelper.uniqueByID(
            allTasks.filter { $0.project?.persistentModelID == project.persistentModelID }
        )
        return taskSortOption.sort(tasks)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
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
        .sheet(isPresented: $showingNewTask) {
            TaskFormView(project: project)
        }
        .onChange(of: showingNewTask) { _, isShowing in
            if !isShowing {
                appState.listRefreshToken = UUID()
            }
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

            if projectTasks.isEmpty {
                EmptyStateView(
                    icon: "checklist",
                    title: "Sem tarefas",
                    message: "Adicione tarefas para organizar o trabalho neste projeto."
                )
                .frame(height: 200)
            } else {
                ForEach(projectTasks, id: \.persistentModelID) { task in
                    TaskRowView(task: task, project: project)
                }
            }
        }
        .id(appState.listRefreshToken)
    }
}

struct TaskRowView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Bindable var task: TaskItem
    let project: Project

    @State private var showingEdit = false

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

            Button {
                showingEdit = true
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        .sheet(isPresented: $showingEdit) {
            TaskFormView(project: project, task: task)
        }
        .onChange(of: showingEdit) { _, isShowing in
            if !isShowing {
                appState.listRefreshToken = UUID()
            }
        }
    }
}
