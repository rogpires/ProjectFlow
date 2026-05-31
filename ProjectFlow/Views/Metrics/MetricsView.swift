import SwiftUI
import SwiftData
import Charts

struct MetricsView: View {
    @Query private var entries: [TimeEntry]
    @Query(sort: \Project.name) private var projects: [Project]

    private var metrics: AdvancedMetrics {
        MetricsService.advancedMetrics(entries: entries, projects: projects)
    }

    private var weekdayNames: [String] {
        Calendar.current.weekdaySymbols
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Métricas Avançadas")
                    .font(.largeTitle.bold())

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(
                        title: "Média diária",
                        value: AppFormatters.formatHours(metrics.dailyAverage),
                        subtitle: "Últimos 30 dias",
                        icon: "sun.max.fill",
                        color: .orange
                    )
                    StatCard(
                        title: "Média semanal",
                        value: AppFormatters.formatHours(metrics.weeklyAverage),
                        subtitle: "Esta semana",
                        icon: "calendar",
                        color: .blue
                    )
                    StatCard(
                        title: "Horário produtivo",
                        value: metrics.mostProductiveHour.map { "\($0):00" } ?? "-",
                        subtitle: "Maior concentração",
                        icon: "clock.fill",
                        color: .purple
                    )
                    StatCard(
                        title: "Dia produtivo",
                        value: metrics.mostProductiveWeekday.map { weekdayNames[$0] } ?? "-",
                        subtitle: "Mais horas registradas",
                        icon: "star.fill",
                        color: .green
                    )
                }

                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Por Projeto")
                            .font(.title3.bold())

                        if metrics.totalByProject.isEmpty {
                            Text("Sem dados")
                                .foregroundStyle(.secondary)
                        } else {
                            Chart(metrics.totalByProject.prefix(8), id: \.project.persistentModelID) { item in
                                BarMark(
                                    x: .value("Horas", item.totalSeconds / 3600),
                                    y: .value("Projeto", item.project.name)
                                )
                                .foregroundStyle(Color(hex: item.project.colorHex).gradient)
                            }
                            .frame(height: 280)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Por Categoria")
                            .font(.title3.bold())

                        ForEach(ProjectCategory.allCases) { category in
                            let seconds = metrics.totalByCategory[category] ?? 0
                            HStack {
                                Label(category.rawValue, systemImage: category.icon)
                                    .font(.subheadline)
                                Spacer()
                                Text(AppFormatters.formatHours(seconds))
                                    .font(.subheadline.monospacedDigit())
                            }
                        }

                        Divider()

                        if let most = metrics.mostProductive {
                            Label("Mais produtivo: \(most.name)", systemImage: "arrow.up.circle.fill")
                                .foregroundStyle(.green)
                        }
                        if let least = metrics.leastProductive, metrics.totalByProject.count > 1 {
                            Label("Menos produtivo: \(least.name)", systemImage: "arrow.down.circle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                    .frame(width: 280)
                    .padding(16)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(24)
        }
        .navigationTitle("Métricas")
    }
}
