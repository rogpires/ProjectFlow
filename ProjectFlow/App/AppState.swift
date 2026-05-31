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
    var listRefreshToken = UUID()

    let timerService: TimerService
    let pomodoroService = PomodoroService()
    let activityLogger = ActivityLogger()
    let syncService: iCloudDriveSyncService

    init() {
        let timer = TimerService()
        let sync = iCloudDriveSyncService()
        timerService = timer
        syncService = sync
        timer.bind(to: self)
        sync.bind(to: self)
    }

    func notifyDataChanged() {
        listRefreshToken = UUID()
        syncService.requestSync()
    }
}
