import SwiftUI
import SwiftData

@main
struct ProjectFlowApp: App {
    @State private var appState = AppState()

    var sharedModelContainer: ModelContainer = ModelContainerFactory.makeShared()

    init() {
        NotificationService.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(appState)
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("Sobre \(AppInfo.displayName)") {
                    appState.selectedSection = .about
                }
            }
            CommandGroup(after: .newItem) {
                Button("Novo Projeto") {
                    appState.selectedSection = .projects
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            MenuBarLabel()
                .environment(appState)
        }
        .modelContainer(sharedModelContainer)
        .menuBarExtraStyle(.window)
    }
}
