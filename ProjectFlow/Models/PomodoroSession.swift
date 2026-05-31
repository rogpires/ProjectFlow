import Foundation
import SwiftData

@Model
final class PomodoroSession {
    var syncId: String = ""
    var updatedAt: Date = Date()
    var startDate: Date
    var endDate: Date?
    var workMinutes: Int
    var breakMinutes: Int
    var completedCycles: Int
    var isWorkPhase: Bool
    var modeRaw: String

    var project: Project?
    var task: TaskItem?

    init(
        workMinutes: Int = 25,
        breakMinutes: Int = 5,
        mode: PomodoroMode = .classic,
        project: Project? = nil,
        task: TaskItem? = nil
    ) {
        self.syncId = UUID().uuidString
        self.updatedAt = Date()
        self.startDate = Date()
        self.endDate = nil
        self.workMinutes = workMinutes
        self.breakMinutes = breakMinutes
        self.completedCycles = 0
        self.isWorkPhase = true
        self.modeRaw = mode.rawValue
        self.project = project
        self.task = task
    }

    var mode: PomodoroMode {
        get { PomodoroMode(rawValue: modeRaw) ?? .classic }
        set { modeRaw = newValue.rawValue }
    }
}
