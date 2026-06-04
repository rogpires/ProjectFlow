//
//  MainView.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showStoreResetAlert = false

    var body: some View {
        @Bindable var state = appState

        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $state.selectedSection) {
                Section("Principal") {
                    ForEach([SidebarSection.dashboard, .projects, .tasks, .timer, .pomodoro]) { section in
                        sidebarRow(section)
                    }
                }
                Section("Análise") {
                    ForEach([SidebarSection.reports, .activity, .metrics, .projectValue]) { section in
                        sidebarRow(section)
                    }
                }
                Section("Organização") {
                    ForEach([SidebarSection.tags, .goals]) { section in
                        sidebarRow(section)
                    }
                }
                Section("Sistema") {
                    sidebarRow(.sync)
                    sidebarRow(.integrations)
                    sidebarRow(.about)
                }

                SidebarPomodoroActiveSection()
                SidebarTimerActiveSection()
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
            .toolbar {
                ToolbarItem {
                    Button {
                        appState.selectedSection = .projects
                    } label: {
                        Label("Novo Projeto", systemImage: "plus")
                    }
                }
            }
        } detail: {
            detailView
                .frame(minWidth: 600, minHeight: 500)
        }
        .searchable(text: $state.searchText, prompt: searchPrompt)
        .onAppear {
            appState.modelContext = context
            TimeEntryCleanupService.cleanupDuplicates(in: context)
            if ModelContainerFactory.didResetStoreDueToMigration {
                showStoreResetAlert = true
                ModelContainerFactory.clearStoreResetFlag()
            }
            if appState.syncService.isConfigured {
                appState.syncService.startPolling()
                Task { await appState.syncService.syncNow() }
            }
        }
        .alert("Banco de dados recriado", isPresented: $showStoreResetAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("O banco local foi recriado após uma atualização. Se você usa sincronização iCloud, os dados devem ser restaurados automaticamente.")
        }
    }

    private var searchPrompt: String {
        switch appState.selectedSection {
        case .projects:
            "Buscar projetos..."
        case .tasks:
            "Buscar tarefas e projetos..."
        default:
            "Buscar..."
        }
    }

    private func sidebarRow(_ section: SidebarSection) -> some View {
        SidebarSectionLabel(section: section)
            .tag(section)
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.selectedSection {
        case .dashboard:
            DashboardView()
        case .projects:
            ProjectsNavigationStack()
        case .tasks:
            NavigationStack {
                AllTasksListView()
            }
        case .timer:
            TimerView()
        case .pomodoro:
            PomodoroView()
        case .reports:
            ReportsView()
        case .activity:
            ActivityHistoryView()
        case .tags:
            TagsView()
        case .goals:
            GoalsView()
        case .metrics:
            MetricsView()
        case .projectValue:
            ProjectValueView()
        case .sync:
            SyncSettingsView()
        case .integrations:
            NavigationStack {
                IntegrationsView()
            }
        case .about:
            AboutView()
        }
    }
}

// MARK: - Sidebar (isolado para não resetar scroll do detalhe a cada tick do timer)

private struct SidebarSectionLabel: View {
    let section: SidebarSection
    @Environment(AppState.self) private var appState

    var body: some View {
        switch section {
        case .timer where appState.timerService.isActive:
            Label {
                HStack {
                    Text(section.rawValue)
                    Spacer(minLength: 8)
                    Text(appState.timerService.displayTime)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            } icon: {
                Image(systemName: section.icon)
            }
        case .pomodoro where appState.pomodoroService.isActive:
            Label {
                HStack {
                    Text(section.rawValue)
                    Spacer(minLength: 8)
                    Text(appState.pomodoroService.displayTime)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            } icon: {
                Image(systemName: section.icon)
            }
        default:
            Label(section.rawValue, systemImage: section.icon)
        }
    }
}

private struct SidebarTimerActiveSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.timerService.isActive {
            Section("Timer Ativo") {
                HStack {
                    Circle()
                        .fill(appState.timerService.state == .running ? .green : .orange)
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading) {
                        Text(appState.timerService.currentProject?.name ?? "")
                            .font(.caption.weight(.medium))
                        Text(appState.timerService.displayTime)
                            .font(.caption.monospacedDigit())
                            .contentTransition(.numericText())
                    }
                }
            }
        }
    }
}

private struct SidebarPomodoroActiveSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.pomodoroService.isActive {
            Section("Pomodoro Ativo") {
                HStack {
                    Image(systemName: appState.pomodoroService.phase == .work ? "flame.fill" : "cup.and.saucer.fill")
                        .foregroundStyle(appState.pomodoroService.phase == .work ? .orange : .green)
                        .font(.caption)
                    VStack(alignment: .leading) {
                        Text(appState.pomodoroService.phaseLabel)
                            .font(.caption.weight(.medium))
                        Text(appState.pomodoroService.displayTime)
                            .font(.caption.monospacedDigit())
                            .contentTransition(.numericText())
                    }
                }
            }
        }
    }
}

private struct ProjectsNavigationStack: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            if let project = appState.selectedProject {
                ProjectDetailView(project: project)
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Button {
                                appState.selectedProject = nil
                            } label: {
                                Label("Projetos", systemImage: "chevron.left")
                            }
                        }
                    }
            } else {
                ProjectsListView()
            }
        }
    }
}

#Preview {
    MainView()
        .environment(AppState())
        .modelContainer(for: [
            Project.self, TaskItem.self, TimeEntry.self,
            PomodoroSession.self, Tag.self, ActivityLog.self, Goal.self
        ], inMemory: true)
}
