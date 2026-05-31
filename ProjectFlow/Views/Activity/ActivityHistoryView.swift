//
//  ActivityHistoryView.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import SwiftUI
import SwiftData

struct ActivityHistoryView: View {
    @Query(sort: \ActivityLog.timestamp, order: .reverse) private var logs: [ActivityLog]
    @State private var filterAction: ActivityAction?

    private var filteredLogs: [ActivityLog] {
        guard let filterAction else { return logs }
        return logs.filter { $0.action == filterAction }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Histórico de Atividades")
                .font(.largeTitle.bold())

            Picker("Filtrar", selection: $filterAction) {
                Text("Todas").tag(nil as ActivityAction?)
                ForEach(ActivityAction.allCases) { action in
                    Text(action.rawValue).tag(action as ActivityAction?)
                }
            }
            .frame(maxWidth: 280)

            if filteredLogs.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "Sem atividades",
                    message: "O histórico será preenchido automaticamente ao usar o timer e gerenciar projetos."
                )
            } else {
                List(filteredLogs) { log in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: log.action.icon)
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(log.action.rawValue)
                                .font(.headline)
                            if let projectName = log.projectName {
                                Text(projectName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let taskName = log.taskName {
                                Text(taskName)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            if !log.details.isEmpty {
                                Text(log.details)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Text(AppFormatters.dateTime.string(from: log.timestamp))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(24)
        .navigationTitle("Histórico")
    }
}
