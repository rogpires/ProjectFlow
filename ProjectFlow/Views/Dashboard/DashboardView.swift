import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \TimeEntry.startDate, order: .reverse) private var entries: [TimeEntry]
    @Query private var projects: [Project]
    @Query private var tasks: [TaskItem]

    private var stats: DashboardStats {
        MetricsService.dashboardStats(entries: entries, projects: projects, tasks: tasks)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Dashboard")
                    .font(.largeTitle.bold())

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
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Project.self, TaskItem.self, TimeEntry.self], inMemory: true)
}
