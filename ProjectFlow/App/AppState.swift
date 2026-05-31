import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppState {
    var selectedSection: SidebarSection = .dashboard
    var selectedProject: Project?
    var searchText: String = ""
    var modelContext: ModelContext?

    let timerService: TimerService
    let pomodoroService = PomodoroService()
    let activityLogger = ActivityLogger()

    init() {
        let timer = TimerService()
        timerService = timer
        timer.bind(to: self)
    }
}
