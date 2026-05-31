import Foundation
import SwiftData

enum ModelContainerFactory {
    private static let storeResetFlagKey = "ProjectFlow.didResetStoreDueToMigration"

    static var didResetStoreDueToMigration: Bool {
        UserDefaults.standard.bool(forKey: storeResetFlagKey)
    }

    static func clearStoreResetFlag() {
        UserDefaults.standard.removeObject(forKey: storeResetFlagKey)
    }

    static func makeShared() -> ModelContainer {
        let schema = Schema([
            Project.self,
            TaskItem.self,
            TimeEntry.self,
            PomodoroSession.self,
            Tag.self,
            ActivityLog.self,
            Goal.self
        ])

        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            NSLog("ProjectFlow: falha ao abrir banco local — \(error.localizedDescription). Tentando recriar store.")
            removePersistentStore(at: applicationSupportURL)
            UserDefaults.standard.set(true, forKey: storeResetFlagKey)

            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }

    private static var applicationSupportURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }

    private static func removePersistentStore(at directory: URL) {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }

        for url in contents where url.lastPathComponent.hasPrefix("default.store") {
            try? fileManager.removeItem(at: url)
        }
    }
}
