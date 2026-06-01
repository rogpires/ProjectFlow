//
//  GoalsView.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import SwiftUI
import SwiftData

struct GoalsView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @Query private var entries: [TimeEntry]
    @State private var showingNewGoal = false

    private static let defaultGoalsSeededKey = "ProjectFlow.defaultGoalsSeeded"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Metas")
                    .font(.largeTitle.bold())
                Spacer()
                Button {
                    showingNewGoal = true
                } label: {
                    Label("Nova Meta", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if goals.isEmpty {
                EmptyStateView(
                    icon: "target",
                    title: "Sem metas",
                    message: "Defina metas como 4h/dia, 20h/semana ou 100h/mês para acompanhar seu progresso."
                )
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(goals, id: \.persistentModelID) { goal in
                        GoalCardView(goal: goal, entries: entries)
                    }
                }
            }
        }
        .padding(24)
        .id(appState.listRefreshToken)
        .navigationTitle("Metas")
        .sheet(isPresented: $showingNewGoal) {
            GoalFormView()
        }
        .onChange(of: showingNewGoal) { _, isShowing in
            if !isShowing {
                appState.listRefreshToken = UUID()
            }
        }
        .onAppear { seedDefaultGoalsIfNeeded() }
    }

    private func seedDefaultGoalsIfNeeded() {
        if UserDefaults.standard.bool(forKey: Self.defaultGoalsSeededKey) { return }

        let existing = (try? context.fetch(FetchDescriptor<Goal>())) ?? []
        guard existing.isEmpty else {
            UserDefaults.standard.set(true, forKey: Self.defaultGoalsSeededKey)
            return
        }

        context.insert(Goal(title: "4 horas por dia", targetHours: 4, period: .daily))
        context.insert(Goal(title: "20 horas por semana", targetHours: 20, period: .weekly))
        context.insert(Goal(title: "100 horas por mês", targetHours: 100, period: .monthly))
        try? context.save()
        UserDefaults.standard.set(true, forKey: Self.defaultGoalsSeededKey)
        appState.notifyDataChanged()
    }
}

struct GoalCardView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    let goal: Goal
    let entries: [TimeEntry]

    private var progress: (current: TimeInterval, target: TimeInterval, progress: Double) {
        MetricsService.goalProgress(goal: goal, entries: entries)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label(goal.period.rawValue, systemImage: goal.period.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { goal.isActive },
                    set: { newValue in
                        goal.isActive = newValue
                        SyncIdentity.touch(&goal.updatedAt)
                        try? context.save()
                        appState.notifyDataChanged()
                    }
                ))
                    .labelsHidden()
            }

            ZStack {
                ProgressRing(progress: progress.progress, lineWidth: 10, color: .accentColor)
                    .frame(width: 100, height: 100)
                VStack(spacing: 2) {
                    Text("\(Int(progress.progress * 100))%")
                        .font(.title2.bold())
                }
            }

            Text(goal.title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("\(AppFormatters.formatHours(progress.current)) de \(AppFormatters.formatHours(progress.target))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(role: .destructive) {
                _ = SyncIdentity.ensure(&goal.syncId)
                appState.syncService.registerDeletion(syncId: goal.syncId)
                context.delete(goal)
                try? context.save()
                appState.notifyDataChanged()
            } label: {
                Text("Remover")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(20)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        .id("\(goal.persistentModelID)-\(appState.listRefreshToken)")
    }
}

struct GoalFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var title = ""
    @State private var targetHours = 4.0
    @State private var period: GoalPeriod = .daily

    var body: some View {
        NavigationStack {
            Form {
                Section("Informações") {
                    TextField("Título", text: $title)
                    Picker("Período", selection: $period) {
                        ForEach(GoalPeriod.allCases) { p in
                            Label(p.rawValue, systemImage: p.icon).tag(p)
                        }
                    }
                }

                Section("Meta") {
                    HStack {
                        Text("Horas alvo")
                        Spacer()
                        TextField("4", value: $targetHours, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    Text("Ex.: 4 para 4 horas por dia, 20 para 20 horas por semana.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Nova Meta")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        let goal = Goal(title: title, targetHours: targetHours, period: period)
                        SyncIdentity.touch(&goal.updatedAt)
                        context.insert(goal)
                        try? context.save()
                        appState.notifyDataChanged()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .frame(minWidth: 420, minHeight: 320)
        }
    }
}
