import SwiftUI
import SwiftData

struct TimerView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Project.name) private var projects: [Project]

    @State private var selectedProject: Project?
    @State private var selectedTask: TaskItem?
    @State private var showingProjectPicker = false

    private var timer: TimerService { appState.timerService }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            if let project = timer.currentProject ?? selectedProject {
                ProjectBadge(project: project)
                if let task = timer.currentTask ?? selectedTask {
                    Text(task.name)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Selecione um projeto e tarefa")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            TimerDisplay(time: timer.displayTime, isRunning: timer.state == .running)

            HStack(spacing: 16) {
                switch timer.state {
                case .idle:
                    Button {
                        showingProjectPicker = true
                    } label: {
                        Label("Selecionar", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        startTimer()
                    } label: {
                        Label("Iniciar", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedProject == nil || selectedTask == nil)

                case .running:
                    Button {
                        timer.pause()
                    } label: {
                        Label("Pausar", systemImage: "pause.fill")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        timer.stop()
                    } label: {
                        Label("Parar", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                case .paused:
                    Button {
                        timer.resume()
                    } label: {
                        Label("Retomar", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        timer.stop()
                    } label: {
                        Label("Parar", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .controlSize(.large)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .navigationTitle("Timer")
        .sheet(isPresented: $showingProjectPicker) {
            TimerPickerSheet(
                projects: projects,
                selectedProject: $selectedProject,
                selectedTask: $selectedTask
            )
        }
        .onAppear {
            selectedProject = timer.currentProject
            selectedTask = timer.currentTask
        }
    }

    private func startTimer() {
        guard let project = selectedProject, let task = selectedTask else { return }
        timer.start(project: project, task: task)
    }
}

struct TimerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let projects: [Project]
    @Binding var selectedProject: Project?
    @Binding var selectedTask: TaskItem?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Projeto", selection: $selectedProject) {
                    Text("Selecione").tag(nil as Project?)
                    ForEach(projects) { project in
                        Text(project.name).tag(project as Project?)
                    }
                }
                .onChange(of: selectedProject) { _, _ in
                    selectedTask = nil
                }

                if let project = selectedProject {
                    Picker("Tarefa", selection: $selectedTask) {
                        Text("Selecione").tag(nil as TaskItem?)
                        ForEach(TimeEntryQueryHelper.uniqueByID(project.tasks)) { task in
                            Text(task.name).tag(task as TaskItem?)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Iniciar Timer")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") { dismiss() }
                        .disabled(selectedProject == nil || selectedTask == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .frame(minWidth: 400, minHeight: 280)
        }
    }
}
