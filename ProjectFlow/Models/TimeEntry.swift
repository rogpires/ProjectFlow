//
//  TimeEntry.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import Foundation
import SwiftData

@Model
final class TimeEntry {
    var syncId: String = ""
    var updatedAt: Date = Date()
    var startDate: Date
    var endDate: Date?
    var notes: String
    var isRunning: Bool

    var project: Project?
    var task: TaskItem?

    @Relationship(deleteRule: .nullify, inverse: \Tag.timeEntries)
    var tags: [Tag]

    init(
        startDate: Date = Date(),
        project: Project? = nil,
        task: TaskItem? = nil,
        notes: String = ""
    ) {
        self.syncId = UUID().uuidString
        self.updatedAt = Date()
        self.startDate = startDate
        self.endDate = nil
        self.notes = notes
        self.isRunning = true
        self.project = project
        self.task = task
        self.tags = []
    }

    var duration: TimeInterval {
        let end = endDate ?? (isRunning ? Date() : startDate)
        return max(0, end.timeIntervalSince(startDate))
    }

    func stop(at date: Date = Date()) {
        endDate = date
        isRunning = false
        task?.refreshActualSeconds()
    }
}
