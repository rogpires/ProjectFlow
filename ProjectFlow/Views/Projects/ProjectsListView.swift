import SwiftUI
import SwiftData

struct ProjectsListView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @State private var showingNewProject = false
    @State private var filterStatus: ProjectStatus?
    @State private var sortOption: ProjectSortOption = .startDateNewest

    private var filteredProjects: [Project] {
        let filtered = projects.filter { project in
            let matchesSearch = appState.searchText.isEmpty ||
                project.name.localizedCaseInsensitiveContains(appState.searchText)
            let matchesStatus = filterStatus == nil || project.status == filterStatus
            return matchesSearch && matchesStatus
        }
        return sortOption.sort(filtered)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Status", selection: $filterStatus) {
                    Text("Todos").tag(nil as ProjectStatus?)
                    ForEach(ProjectStatus.allCases) { status in
                        Text(status.rawValue).tag(status as ProjectStatus?)
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

            if filteredProjects.isEmpty {
                EmptyStateView(
                    icon: "folder.badge.plus",
                    title: "Nenhum projeto",
                    message: "Crie seu primeiro projeto para começar a rastrear tempo e custos."
                )
            } else {
                List {
                    ForEach(filteredProjects, id: \.persistentModelID) { project in
                        Button {
                            appState.selectedProject = project
                        } label: {
                            ProjectRowView(project: project)
                        }
                        .buttonStyle(.plain)
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
