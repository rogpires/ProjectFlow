//
//  ReportsView.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import SwiftUI
import SwiftData

struct ReportsView: View {
    @Query(sort: \TimeEntry.startDate, order: .reverse) private var queriedEntries: [TimeEntry]
    @Query(sort: \Project.name) private var projects: [Project]

    @State private var period: ReportPeriod = .week
    @State private var selectedProject: Project?
    @State private var exportFormat: ExportFormat = .csv

    private var allEntries: [TimeEntry] {
        TimeEntryQueryHelper.uniqueByID(queriedEntries)
    }

    private var filteredEntries: [TimeEntry] {
        TimeEntryQueryHelper.displayEntries(
            ExportService.filteredEntries(allEntries, period: period, project: selectedProject)
        )
    }

    private var totalHours: Double {
        filteredEntries.reduce(0) { $0 + $1.duration } / 3600
    }

    private var totalValue: Double {
        filteredEntries.reduce(0) { total, entry in
            total + (entry.duration / 3600) * (entry.project?.hourlyRate ?? 0)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Relatórios")
                    .font(.largeTitle.bold())

                HStack(spacing: 16) {
                    Picker("Período", selection: $period) {
                        ForEach(ReportPeriod.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .frame(width: 160)

                    Picker("Projeto", selection: $selectedProject) {
                        Text("Todos").tag(nil as Project?)
                        ForEach(projects) { p in
                            Text(p.name).tag(p as Project?)
                        }
                    }
                    .frame(width: 200)

                    Spacer()

                    Picker("Formato", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .frame(width: 120)

                    Button {
                        ExportService.exportToFile(entries: filteredEntries, format: exportFormat, period: period)
                    } label: {
                        Label("Exportar", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(
                        title: "Registros",
                        value: "\(filteredEntries.count)",
                        subtitle: period.rawValue,
                        icon: "list.bullet",
                        color: .blue
                    )
                    StatCard(
                        title: "Horas",
                        value: String(format: "%.1fh", totalHours),
                        subtitle: "Total no período",
                        icon: "clock.fill",
                        color: .green
                    )
                    StatCard(
                        title: "Valor",
                        value: AppFormatters.formatCurrency(totalValue),
                        subtitle: "Investimento",
                        icon: "dollarsign.circle.fill",
                        color: .orange
                    )
                }

                if filteredEntries.isEmpty {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "Sem registros",
                        message: "Use o timer e encerre a sessão para gerar relatórios."
                    )
                    .frame(minHeight: 200)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredEntries, id: \.persistentModelID) { entry in
                            TimeEntryRowView(entry: entry)
                                .padding(.vertical, 8)
                            Divider()
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Relatórios")
    }
}

struct TimeEntryRowView: View {
    let entry: TimeEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.project?.name ?? "-")
                    .font(.headline)
                Text(entry.task?.name ?? "-")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(AppFormatters.formatDuration(entry.duration))
                    .font(.subheadline.monospacedDigit())
                Text(AppFormatters.dateTime.string(from: entry.startDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
