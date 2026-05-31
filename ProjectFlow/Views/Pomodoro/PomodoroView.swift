//
//  PomodoroView.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import SwiftUI
import SwiftData

struct PomodoroView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \PomodoroSession.startDate, order: .reverse) private var sessions: [PomodoroSession]
    @Query(sort: \Project.name) private var projects: [Project]

    @State private var selectedProject: Project?
    @State private var selectedTask: TaskItem?

    private var pomodoro: PomodoroService { appState.pomodoroService }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 24) {
                Picker("Modo", selection: Bindable(appState.pomodoroService).mode) {
                    ForEach(PomodoroMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)

                if pomodoro.mode == .custom {
                    HStack {
                        Stepper("Trabalho: \(pomodoro.customWorkMinutes) min", value: Bindable(appState.pomodoroService).customWorkMinutes, in: 5...120, step: 5)
                        Stepper("Pausa: \(pomodoro.customBreakMinutes) min", value: Bindable(appState.pomodoroService).customBreakMinutes, in: 1...60, step: 1)
                    }
                    .font(.caption)
                }

                Text(pomodoro.phaseLabel)
                    .font(.headline)
                    .foregroundStyle(pomodoro.phase == .work ? .orange : .green)

                ZStack {
                    ProgressRing(
                        progress: ringProgress,
                        lineWidth: 8,
                        color: pomodoro.phase == .work ? .orange : .green
                    )
                    .frame(width: 200, height: 200)

                    TimerDisplay(
                        time: pomodoro.displayTime,
                        isRunning: pomodoro.phase != .idle
                    )
                    .font(.system(size: 36, weight: .light, design: .monospaced))
                }

                Toggle("Sons", isOn: Bindable(appState.pomodoroService).soundEnabled)

                HStack(spacing: 16) {
                    if pomodoro.phase == .idle {
                        Button {
                            pomodoro.start(project: selectedProject, task: selectedTask)
                            saveSession()
                        } label: {
                            Label("Iniciar", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            pomodoro.stop()
                        } label: {
                            Label("Parar", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            pomodoro.skipPhase()
                        } label: {
                            Label("Pular", systemImage: "forward.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .controlSize(.large)

                Text("\(pomodoro.completedCycles) ciclos completos")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Form {
                    Picker("Projeto", selection: $selectedProject) {
                        Text("Nenhum").tag(nil as Project?)
                        ForEach(projects) { p in Text(p.name).tag(p as Project?) }
                    }
                    if let project = selectedProject {
                        Picker("Tarefa", selection: $selectedTask) {
                            Text("Nenhuma").tag(nil as TaskItem?)
                            ForEach(project.tasks) { t in Text(t.name).tag(t as TaskItem?) }
                        }
                    }
                }
                .formStyle(.grouped)
                .frame(maxWidth: 320)
            }
            .padding(32)
            .frame(maxWidth: .infinity)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Estatísticas")
                    .font(.title3.bold())
                Text("Total de ciclos: \(totalCompletedCycles)")
                    .foregroundStyle(.secondary)
                List(sessions.prefix(20)) { session in
                    VStack(alignment: .leading) {
                        Text(session.project?.name ?? "Sem projeto")
                            .font(.headline)
                        Text("\(session.completedCycles) ciclos · \(session.mode.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
            .frame(width: 280)
        }
        .navigationTitle("Pomodoro")
    }

    private var ringProgress: Double {
        let total = Double(pomodoro.phase == .work ? pomodoro.workDuration : pomodoro.breakDuration) * 60
        guard total > 0, pomodoro.phase != .idle else { return 0 }
        return 1 - (pomodoro.remainingSeconds / total)
    }

    private var totalCompletedCycles: Int {
        sessions.reduce(0) { $0 + $1.completedCycles }
    }

    private func saveSession() {
        if let session = pomodoro.currentSession {
            context.insert(session)
            try? context.save()
        }
    }
}
