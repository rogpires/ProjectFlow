import SwiftUI
import SwiftData

struct TaskFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let project: Project
    var task: TaskItem?

    @State private var name = ""
    @State private var description = ""
    @State private var priority: TaskPriority = .medium
    @State private var status: TaskStatus = .todo
    @State private var estimatedHours = 0.0

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nome", text: $name)
                TextField("Descrição", text: $description, axis: .vertical)
                    .lineLimit(2...4)
                Picker("Prioridade", selection: $priority) {
                    ForEach(TaskPriority.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                Picker("Status", selection: $status) {
                    ForEach(TaskStatus.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                HStack {
                    Text("Tempo estimado (horas)")
                    Spacer()
                    TextField("0", value: $estimatedHours, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(task == nil ? "Nova Tarefa" : "Editar Tarefa")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadTask() }
            .frame(minWidth: 400, minHeight: 320)
        }
    }

    private func loadTask() {
        guard let task else { return }
        name = task.name
        description = task.taskDescription
        priority = task.priority
        status = task.status
        estimatedHours = task.estimatedSeconds / 3600
    }

    private func save() {
        if let task {
            task.name = name
            task.taskDescription = description
            task.priority = priority
            task.status = status
            task.estimatedSeconds = estimatedHours * 3600
            SyncIdentity.touch(&task.updatedAt)
            if status == .completed {
                appState.activityLogger.log(
                    action: .taskCompleted,
                    project: project,
                    task: task,
                    context: context
                )
            }
        } else {
            let newTask = TaskItem(
                name: name,
                taskDescription: description,
                priority: priority,
                status: status,
                estimatedSeconds: estimatedHours * 3600,
                project: project
            )
            context.insert(newTask)
            SyncIdentity.touch(&project.updatedAt)
            appState.activityLogger.log(
                action: .taskCreated,
                details: name,
                project: project,
                task: newTask,
                context: context
            )
        }
        do {
            try context.save()
            appState.notifyDataChanged()
            dismiss()
        } catch {}
    }
}
