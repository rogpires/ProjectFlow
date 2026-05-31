import Foundation
import SwiftData

@Model
final class Tag {
    var name: String
    var colorHex: String
    var createdAt: Date

    var projects: [Project]
    var timeEntries: [TimeEntry]

    init(name: String, colorHex: String = "#8E8E93") {
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
        self.projects = []
        self.timeEntries = []
    }

    var displayName: String {
        name.hasPrefix("#") ? name : "#\(name)"
    }
}
