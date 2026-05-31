import Foundation
import SwiftData
import UserNotifications

@MainActor
@Observable
final class ActivityLogger {
    func log(
        action: ActivityAction,
        details: String = "",
        project: Project? = nil,
        task: TaskItem? = nil,
        context: ModelContext
    ) {
        let entry = ActivityLog(action: action, details: details, project: project, task: task)
        context.insert(entry)
        try? context.save()
    }
}

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notify(title: String, body: String, playSound: Bool = true) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if playSound {
            content.sound = .default
        }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
