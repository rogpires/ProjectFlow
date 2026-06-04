//
//  DashboardView.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @Query(sort: \TimeEntry.startDate, order: .reverse) private var entries: [TimeEntry]
    @Query private var tasks: [TaskItem]

    @State private var playClockEntrance = false

    private var stats: DashboardStats {
        MetricsService.dashboardStats(entries: entries, projects: projects, tasks: tasks)
    }

    private var sortedProjects: [Project] {
        let timer = appState.timerService
        return projects.sorted { lhs, rhs in
            let lhsRunning = timer.isActive
                && timer.currentProject?.persistentModelID == lhs.persistentModelID
            let rhsRunning = timer.isActive
                && timer.currentProject?.persistentModelID == rhs.persistentModelID
            if lhsRunning != rhsRunning { return lhsRunning }
            return statusRank(lhs.status) < statusRank(rhs.status)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                liveProjectsSection

                Group {
                    Text("Hoje")
                        .font(.title3.weight(.semibold))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(
                            title: "Horas trabalhadas",
                            value: AppFormatters.formatHours(stats.todayHours),
                            subtitle: "Registradas hoje",
                            icon: "clock.fill",
                            color: .blue
                        )
                        StatCard(
                            title: "Projetos ativos",
                            value: "\(stats.todayActiveProjects)",
                            subtitle: "Com tempo hoje",
                            icon: "folder.fill",
                            color: .green
                        )
                        StatCard(
                            title: "Tarefas concluídas",
                            value: "\(stats.todayCompletedTasks)",
                            subtitle: "Finalizadas hoje",
                            icon: "checkmark.circle.fill",
                            color: .orange
                        )
                    }
                }

                Group {
                    Text("Semana")
                        .font(.title3.weight(.semibold))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(
                            title: "Horas totais",
                            value: AppFormatters.formatHours(stats.weekHours),
                            subtitle: "Esta semana",
                            icon: "calendar",
                            color: .purple
                        )
                        StatCard(
                            title: "Média diária",
                            value: AppFormatters.formatHours(stats.weekDailyAverage),
                            subtitle: "Por dia útil",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .teal
                        )
                    }
                }

                Group {
                    Text("Mês")
                        .font(.title3.weight(.semibold))
                    HStack(spacing: 16) {
                        StatCard(
                            title: "Horas totais",
                            value: AppFormatters.formatHours(stats.monthHours),
                            subtitle: "Este mês",
                            icon: "calendar.badge.clock",
                            color: .indigo
                        )

                        if !stats.monthDailyData.isEmpty {
                            Chart(stats.monthDailyData, id: \.date) { item in
                                BarMark(
                                    x: .value("Dia", item.date, unit: .day),
                                    y: .value("Horas", item.hours / 3600)
                                )
                                .foregroundStyle(.blue.gradient)
                            }
                            .chartYAxisLabel("Horas")
                            .frame(height: 180)
                            .padding(16)
                            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
        .onAppear { scheduleClockEntrance() }
        .onDisappear { playClockEntrance = false }
    }

    private func scheduleClockEntrance() {
        playClockEntrance = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            playClockEntrance = true
        }
    }

    private var liveProjectsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Projetos ao vivo")
                        .font(.title2.bold())
                    Text("Status e tempo de cada projeto — toque para abrir")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if appState.timerService.isActive {
                    liveTimerBadge
                }
            }

            if sortedProjects.isEmpty {
                ContentUnavailableView(
                    "Nenhum projeto",
                    systemImage: "folder.badge.plus",
                    description: Text("Crie um projeto para ver os relógios de status aqui.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(sortedProjects.enumerated()), id: \.element.persistentModelID) { index, project in
                            projectClockCard(for: project, staggerIndex: index)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private var liveTimerBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(appState.timerService.state == .running ? .green : .orange)
                .frame(width: 8, height: 8)
            Text(appState.timerService.displayTime)
                .font(.caption.monospacedDigit().weight(.semibold))
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.green.opacity(0.12), in: Capsule())
    }

    private func projectClockCard(for project: Project, staggerIndex: Int) -> some View {
        let timer = appState.timerService
        let isRunning = timer.isActive
            && timer.currentProject?.persistentModelID == project.persistentModelID
        return ProjectStatusClockCard(
            project: project,
            hoursToday: MetricsService.hoursToday(for: project, entries: entries),
            isTimerRunning: isRunning,
            liveTime: isRunning ? timer.displayTime : nil,
            staggerIndex: staggerIndex,
            animateEntrance: playClockEntrance,
            onOpen: { openProject(project) }
        )
    }

    private func openProject(_ project: Project) {
        appState.selectedProject = project
        appState.selectedSection = .projects
    }

    private func statusRank(_ status: ProjectStatus) -> Int {
        switch status {
        case .inProgress: 0
        case .planning: 1
        case .paused: 2
        case .completed: 3
        }
    }
}

#Preview {
    DashboardView()
        .environment(AppState())
        .modelContainer(for: [Project.self, TaskItem.self, TimeEntry.self], inMemory: true)
}
