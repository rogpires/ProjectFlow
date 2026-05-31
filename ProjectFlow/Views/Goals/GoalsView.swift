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
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @Query private var entries: [TimeEntry]
    @State private var showingNewGoal = false

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
                    ForEach(goals) { goal in
                        GoalCardView(goal: goal, entries: entries)
                    }
                }
            }
        }
        .padding(24)
        .navigationTitle("Metas")
        .sheet(isPresented: $showingNewGoal) {
            GoalFormView()
        }
        .onAppear { seedDefaultGoalsIfNeeded() }
    }

    private func seedDefaultGoalsIfNeeded() {
        guard goals.isEmpty else { return }
        context.insert(Goal(title: "4 horas por dia", targetHours: 4, period: .daily))
        context.insert(Goal(title: "20 horas por semana", targetHours: 20, period: .weekly))
        context.insert(Goal(title: "100 horas por mês", targetHours: 100, period: .monthly))
        try? context.save()
    }
}

struct GoalCardView: View {
    @Environment(\.modelContext) private var context
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
                Toggle("", isOn: Bindable(goal).isActive)
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
                context.delete(goal)
                try? context.save()
            } label: {
                Text("Remover")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(20)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct GoalFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var targetHours = 4.0
    @State private var period: GoalPeriod = .daily

    var body: some View {
        NavigationStack {
            Form {
                TextField("Título", text: $title)
                Picker("Período", selection: $period) {
                    ForEach(GoalPeriod.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                HStack {
                    Text("Horas alvo")
                    Spacer()
                    TextField("4", value: $targetHours, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
            }
            .navigationTitle("Nova Meta")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        context.insert(Goal(title: title, targetHours: targetHours, period: period))
                        try? context.save()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .frame(minWidth: 360, minHeight: 240)
        }
    }
}
