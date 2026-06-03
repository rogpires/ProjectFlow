//
//  MenuBarView.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \Project.name) private var projects: [Project]

    @State private var showingPicker = false
    @State private var pickerProject: Project?
    @State private var pickerTask: TaskItem?

    private var timer: TimerService { appState.timerService }
    private var pomodoro: PomodoroService { appState.pomodoroService }

    var body: some View {
        @Bindable var state = appState

        VStack(alignment: .leading, spacing: 12) {
            if state.pomodoroService.isActive {
                pomodoroPanel
                if state.timerService.isActive {
                    Divider()
                }
            }

            if state.timerService.isActive {
                timerPanel
            } else if !state.pomodoroService.isActive {
                Text("Nenhum timer ativo")
                    .foregroundStyle(.secondary)
            }

            Divider()

            if timer.state == .idle {
                Button("Iniciar Timer") {
                    showingPicker = true
                }
            } else if timer.isActive {
                Button("Trocar Projeto/Tarefa") {
                    pickerProject = timer.currentProject
                    pickerTask = timer.currentTask
                    showingPicker = true
                }
            }

            Divider()

            Button("Abrir ProjectFlow") {
                NSApp.activate(ignoringOtherApps: true)
                if pomodoro.isActive {
                    appState.selectedSection = .pomodoro
                } else if timer.isActive {
                    appState.selectedSection = .timer
                }
                if let window = NSApp.windows.first(where: { $0.title.contains("ProjectFlow") || $0.isMainWindow }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
        .padding(12)
        .frame(width: 240)
        .onAppear {
            if appState.modelContext == nil {
                appState.modelContext = context
            }
        }
        .sheet(isPresented: $showingPicker) {
            MenuBarPickerSheet(
                projects: projects,
                selectedProject: $pickerProject,
                selectedTask: $pickerTask,
                onConfirm: { project, task in
                    if timer.isActive {
                        timer.switchProject(project, task: task)
                    } else {
                        timer.start(project: project, task: task)
                    }
                }
            )
        }
    }

    private var timerPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(timer.state == .running ? .green : .orange)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(timer.currentProject?.name ?? "Sem projeto")
                        .font(.headline)
                    Text(timer.currentTask?.name ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(timer.displayTime)
                .font(.system(size: 28, weight: .light, design: .monospaced))
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText())
            HStack {
                if timer.state == .running {
                    Button("Pausar") { timer.pause() }
                } else if timer.state == .paused {
                    Button("Retomar") { timer.resume() }
                }
                Button("Parar") { timer.stop() }
            }
        }
    }

    private var pomodoroPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: pomodoro.phase == .work ? "flame.fill" : "cup.and.saucer.fill")
                    .foregroundStyle(pomodoro.phase == .work ? .orange : .green)
                Text(pomodoro.phaseLabel)
                    .font(.headline)
            }
            Text(pomodoro.displayTime)
                .font(.system(size: 28, weight: .light, design: .monospaced))
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText())
            if let name = pomodoro.currentProject?.name {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Parar") { pomodoro.stop() }
                Button("Pular fase") { pomodoro.skipPhase() }
            }
        }
    }
}

struct MenuBarPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let projects: [Project]
    @Binding var selectedProject: Project?
    @Binding var selectedTask: TaskItem?
    let onConfirm: (Project, TaskItem) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Picker("Projeto", selection: $selectedProject) {
                    ForEach(projects) { project in
                        Text(project.name).tag(project as Project?)
                    }
                }
                if let project = selectedProject {
                    Picker("Tarefa", selection: $selectedTask) {
                        ForEach(TimeEntryQueryHelper.uniqueByID(project.tasks)) { task in
                            Text(task.name).tag(task as TaskItem?)
                        }
                    }
                }
            }
            .navigationTitle("Timer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") {
                        if let p = selectedProject, let t = selectedTask {
                            onConfirm(p, t)
                            dismiss()
                        }
                    }
                    .disabled(selectedProject == nil || selectedTask == nil)
                }
            }
            .frame(minWidth: 360, minHeight: 200)
        }
    }
}

struct MenuBarLabel: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        let pomodoro = state.pomodoroService
        let timer = state.timerService

        HStack(spacing: 6) {
            if pomodoro.isActive {
                HStack(spacing: 3) {
                    Image(systemName: pomodoro.phase == .work ? "flame.fill" : "cup.and.saucer.fill")
                        .foregroundStyle(pomodoro.phase == .work ? .orange : .green)
                        .font(.caption2)
                    Text(pomodoro.displayTime)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }

            if timer.isActive {
                HStack(spacing: 3) {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(timer.state == .running ? .green : .orange)
                        .font(.caption2)
                    Text(timer.displayTime)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }

            if !pomodoro.isActive && !timer.isActive {
                Image(systemName: "timer")
                Text("ProjectFlow")
            }
        }
    }
}
