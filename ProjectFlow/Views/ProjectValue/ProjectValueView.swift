import SwiftUI
import SwiftData
import Charts

struct ProjectValueView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Project.name) private var projects: [Project]
    @State private var selectedProject: Project?

    private var project: Project? {
        selectedProject ?? projects.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Valor do Projeto")
                        .font(.largeTitle.bold())
                    Spacer()
                    Picker("Projeto", selection: $selectedProject) {
                        ForEach(projects) { p in
                            Text(p.name).tag(p as Project?)
                        }
                    }
                    .frame(width: 220)
                }

                if let project {
                    let metrics = MetricsService.projectValueMetrics(project: project)

                    HStack(spacing: 16) {
                        Image(systemName: project.iconName)
                            .font(.system(size: 48))
                            .foregroundStyle(Color(hex: project.colorHex))
                        VStack(alignment: .leading) {
                            Text(project.name)
                                .font(.title.bold())
                            Text("R$ \(Int(project.hourlyRate))/hora")
                                .foregroundStyle(.secondary)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(
                            title: "Horas investidas",
                            value: AppFormatters.formatHours(metrics.investedHours),
                            subtitle: "Tempo total registrado",
                            icon: "clock.fill",
                            color: Color(hex: project.colorHex)
                        )
                        StatCard(
                            title: "Valor acumulado",
                            value: AppFormatters.formatCurrency(metrics.accumulatedValue),
                            subtitle: "Horas × valor/hora",
                            icon: "dollarsign.circle.fill",
                            color: .green
                        )
                        StatCard(
                            title: "Média diária",
                            value: AppFormatters.formatHours(metrics.dailyAverage),
                            subtitle: "Desde a criação",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .blue
                        )
                    }

                    HStack(spacing: 16) {
                        StatCard(
                            title: "Tempo total",
                            value: AppFormatters.formatDuration(metrics.totalTime),
                            subtitle: "HH:MM:SS",
                            icon: "timer",
                            color: .purple
                        )
                        StatCard(
                            title: "ROI estimado",
                            value: AppFormatters.formatCurrency(metrics.estimatedROI),
                            subtitle: "Retorno projetado",
                            icon: "arrow.up.right.circle.fill",
                            color: .orange
                        )
                        StatCard(
                            title: "Valor estimado",
                            value: AppFormatters.formatCurrency(project.estimatedValue),
                            subtitle: "Com base em tarefas",
                            icon: "chart.bar.fill",
                            color: .teal
                        )
                    }

                    if !project.timeEntries.isEmpty {
                        Text("Evolução de investimento")
                            .font(.title3.bold())

                        Chart(dailyInvestment(for: project), id: \.date) { item in
                            AreaMark(
                                x: .value("Dia", item.date, unit: .day),
                                y: .value("Valor", item.value)
                            )
                            .foregroundStyle(Color(hex: project.colorHex).gradient.opacity(0.6))
                            LineMark(
                                x: .value("Dia", item.date, unit: .day),
                                y: .value("Valor", item.value)
                            )
                            .foregroundStyle(Color(hex: project.colorHex))
                        }
                        .chartYAxisLabel("R$")
                        .frame(height: 200)
                        .padding(16)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    EmptyStateView(
                        icon: "dollarsign.circle",
                        title: "Selecione um projeto",
                        message: "Crie um projeto para visualizar o valor investido e métricas financeiras."
                    )
                }
            }
            .padding(24)
        }
        .navigationTitle("Valor do Projeto")
        .onAppear {
            if selectedProject == nil { selectedProject = projects.first }
        }
    }

    private func dailyInvestment(for project: Project) -> [(date: Date, value: Double)] {
        let calendar = Calendar.current
        var cumulative: Double = 0
        var result: [(date: Date, value: Double)] = []

        let grouped = Dictionary(grouping: project.timeEntries) { entry in
            calendar.startOfDay(for: entry.startDate)
        }

        for date in grouped.keys.sorted() {
            let daySeconds = grouped[date]?.reduce(0) { $0 + $1.duration } ?? 0
            cumulative += (daySeconds / 3600) * project.hourlyRate
            result.append((date: date, value: cumulative))
        }
        return result
    }
}
