//
//  AllTasksListView.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import SwiftUI
import SwiftData

enum AllTasksStatusFilter: String, CaseIterable, Identifiable {
    case pending = "Pendentes"
    case all = "Todas"
    case todo = "A fazer"
    case inProgress = "Em andamento"
    case completed = "Concluídas"
    case cancelled = "Canceladas"

    var id: String { rawValue }

    func matches(_ status: TaskStatus) -> Bool {
        switch self {
        case .pending:
            status == .todo || status == .inProgress
        case .all:
            true
        case .todo:
            status == .todo
        case .inProgress:
            status == .inProgress
        case .completed:
            status == .completed
        case .cancelled:
            status == .cancelled
        }
    }
}

struct AllTasksListView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var allTasks: [TaskItem]

    @State private var statusFilter: AllTasksStatusFilter = .pending
    @State private var sortOption: TaskSortOption = .priority

    private var filteredTasks: [TaskItem] {
        let unique = TimeEntryQueryHelper.uniqueByID(allTasks)
        let filtered = unique.filter { task in
            guard statusFilter.matches(task.status) else { return false }
            let query = appState.searchText.trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else { return true }
            let matchesTask = task.name.localizedCaseInsensitiveContains(query)
            let matchesProject = task.project?.name.localizedCaseInsensitiveContains(query) ?? false
            return matchesTask || matchesProject
        }
        return sortOption.sort(filtered)
    }

    private var groupedByProject: [(project: Project, tasks: [TaskItem])] {
        var groups: [PersistentIdentifier: (project: Project, tasks: [TaskItem])] = [:]
        for task in filteredTasks {
            guard let project = task.project else { continue }
            let key = project.persistentModelID
            if var group = groups[key] {
                group.tasks.append(task)
                groups[key] = group
            } else {
                groups[key] = (project, [task])
            }
        }
        return groups.values.sorted {
            $0.project.name.localizedCaseInsensitiveCompare($1.project.name) == .orderedAscending
        }
    }

    private var orphanTasks: [TaskItem] {
        filteredTasks.filter { $0.project == nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            filtersBar
                .padding()

            if filteredTasks.isEmpty {
                EmptyStateView(
                    icon: "checklist",
                    title: "Nenhuma tarefa",
                    message: emptyMessage
                )
            } else {
                List {
                    ForEach(groupedByProject, id: \.project.persistentModelID) { group in
                        Section {
                            ForEach(group.tasks, id: \.persistentModelID) { task in
                                TaskRowView(task: task, project: group.project)
                            }
                        } header: {
                            ProjectSectionHeader(project: group.project, taskCount: group.tasks.count) {
                                openProject(group.project)
                            }
                        }
                    }

                    if !orphanTasks.isEmpty {
                        Section("Sem projeto") {
                            ForEach(orphanTasks, id: \.persistentModelID) { task in
                                orphanTaskRow(task)
                            }
                        }
                    }
                }
            }
        }
        .id(appState.listRefreshToken)
        .navigationTitle("Tarefas")
    }

    private var filtersBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Status", selection: $statusFilter) {
                ForEach(AllTasksStatusFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Picker("Ordenar", selection: $sortOption) {
                    ForEach(TaskSortOption.allCases) { option in
                        Label(option.rawValue, systemImage: option.icon).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()

                Spacer()

                Text("\(filteredTasks.count) tarefa\(filteredTasks.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyMessage: String {
        switch statusFilter {
        case .pending:
            return "Não há tarefas pendentes. Crie tarefas nos projetos ou altere o filtro."
        case .all:
            return "Crie tarefas dentro de um projeto para vê-las aqui."
        default:
            return "Nenhuma tarefa com este status. Tente outro filtro."
        }
    }

    private func openProject(_ project: Project) {
        appState.selectedProject = project
        appState.selectedSection = .projects
    }

    @ViewBuilder
    private func orphanTaskRow(_ task: TaskItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.headline)
                Text(task.status.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(AppFormatters.formatHours(task.totalWorkedSeconds))
                .font(.subheadline.monospacedDigit())
        }
        .padding(.vertical, 4)
    }
}

private struct ProjectSectionHeader: View {
    let project: Project
    let taskCount: Int
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                Image(systemName: project.iconName)
                    .foregroundStyle(Color(hex: project.colorHex))
                Text(project.name)
                    .font(.headline)
                Text("(\(taskCount))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        AllTasksListView()
    }
    .environment(AppState())
    .modelContainer(for: [Project.self, TaskItem.self], inMemory: true)
}
