import Foundation
import SwiftData

@Model
final class ActivityLog {
    var syncId: String = ""
    var updatedAt: Date = Date()
    var timestamp: Date
    var actionRaw: String
    var details: String

    var projectID: UUID?
    var projectName: String?
    var taskID: UUID?
    var taskName: String?

    init(
        action: ActivityAction,
        details: String = "",
        project: Project? = nil,
        task: TaskItem? = nil
    ) {
        self.syncId = UUID().uuidString
        self.updatedAt = Date()
        self.timestamp = Date()
        self.actionRaw = action.rawValue
        self.details = details
        self.projectName = project?.name
        self.taskName = task?.name
    }

    var action: ActivityAction {
        ActivityAction(rawValue: actionRaw) ?? .timerStarted
    }
}
