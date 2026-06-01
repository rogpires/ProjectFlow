//
//  ProjectsListView.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import SwiftUI
import SwiftData

struct ProjectsListView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @State private var showingNewProject = false
    @State private var listFilter: ProjectListFilter = .all
    @State private var sortOption: ProjectSortOption = .startDateNewest

    private var matchingProjects: [Project] {
        let filtered = projects.filter { project in
            let matchesSearch = appState.searchText.isEmpty ||
                project.name.localizedCaseInsensitiveContains(appState.searchText)
            let matchesFilter = listFilter.includes(project.status)
            return matchesSearch && matchesFilter
        }
        return sortOption.sort(filtered)
    }

    private var listSections: [(filter: ProjectListFilter, projects: [Project])] {
        switch listFilter {
        case .all:
            return [
                (.active, projects(in: matchingProjects, filter: .active)),
                (.paused, projects(in: matchingProjects, filter: .paused)),
                (.completed, projects(in: matchingProjects, filter: .completed))
            ].filter { !$0.projects.isEmpty }
        default:
            guard !matchingProjects.isEmpty else { return [] }
            return [(listFilter, matchingProjects)]
        }
    }

    private func projects(in list: [Project], filter: ProjectListFilter) -> [Project] {
        list.filter { filter.includes($0.status) }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Status", selection: $listFilter) {
                    ForEach(ProjectListFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 12) {
                    Picker("Ordenar", selection: $sortOption) {
                        ForEach(ProjectSortOption.allCases) { option in
                            Label(option.rawValue, systemImage: option.icon).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()

                    Spacer()

                    Button {
                        showingNewProject = true
                    } label: {
                        Label("Novo Projeto", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()

            if listSections.isEmpty {
                EmptyStateView(
                    icon: "folder.badge.plus",
                    title: "Nenhum projeto",
                    message: emptyMessage
                )
            } else {
                List {
                    ForEach(listSections, id: \.filter.id) { section in
                        Section {
                            ForEach(section.projects, id: \.persistentModelID) { project in
                                Button {
                                    appState.selectedProject = project
                                } label: {
                                    ProjectRowView(project: project)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            ProjectListSectionHeader(
                                filter: section.filter,
                                count: section.projects.count
                            )
                        }
                    }
                }
            }
        }
        .id(appState.listRefreshToken)
        .sheet(isPresented: $showingNewProject) {
            ProjectFormView()
        }
        .onChange(of: showingNewProject) { _, isShowing in
            if !isShowing {
                appState.listRefreshToken = UUID()
            }
        }
        .navigationTitle("Projetos")
    }

    private var emptyMessage: String {
        switch listFilter {
        case .all:
            return "Crie seu primeiro projeto para começar a rastrear tempo e custos."
        case .active:
            return "Não há projetos em planejamento ou em andamento."
        case .paused:
            return "Não há projetos pausados."
        case .completed:
            return "Não há projetos finalizados."
        }
    }
}

private struct ProjectListSectionHeader: View {
    let filter: ProjectListFilter
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Label(filter.sectionTitle, systemImage: filter.sectionIcon)
            Text("(\(count))")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline.weight(.semibold))
    }
}

struct ProjectRowView: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: project.iconName)
                .font(.title2)
                .foregroundStyle(Color(hex: project.colorHex))
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Label(project.category.rawValue, systemImage: project.category.icon)
                    Label(project.status.rawValue, systemImage: project.status.icon)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(AppFormatters.formatHours(project.totalSeconds))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text(AppFormatters.formatCurrency(project.investedValue))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ProjectsListView()
    }
    .environment(AppState())
    .modelContainer(for: Project.self, inMemory: true)
}
