import Foundation
import SwiftData

@Model
final class TaskItem {
    var name: String
    var taskDescription: String
    var priorityRaw: String
    var statusRaw: String
    var estimatedSeconds: TimeInterval
    var actualSeconds: TimeInterval
    var createdAt: Date
    var completedAt: Date?

    var project: Project?

    @Relationship(deleteRule: .cascade, inverse: \TimeEntry.task)
    var timeEntries: [TimeEntry]

    init(
        name: String,
        taskDescription: String = "",
        priority: TaskPriority = .medium,
        status: TaskStatus = .todo,
        estimatedSeconds: TimeInterval = 0,
        project: Project? = nil
    ) {
        self.name = name
        self.taskDescription = taskDescription
        self.priorityRaw = priority.rawValue
        self.statusRaw = status.rawValue
        self.estimatedSeconds = estimatedSeconds
        self.actualSeconds = 0
        self.createdAt = Date()
        self.completedAt = nil
        self.project = project
        self.timeEntries = []
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .todo }
        set {
            statusRaw = newValue.rawValue
            if newValue == .completed && completedAt == nil {
                completedAt = Date()
            }
        }
    }

    func refreshActualSeconds() {
        actualSeconds = timeEntries.reduce(0) { $0 + $1.duration }
    }
}
