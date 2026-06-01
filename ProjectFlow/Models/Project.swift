//
//  Project.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import Foundation
import SwiftData

@Model
final class Project {
    var syncId: String = ""
    var updatedAt: Date = Date()
    var name: String
    var projectDescription: String
    var categoryRaw: String
    var statusRaw: String
    var createdAt: Date
    var completedAt: Date?
    var colorHex: String
    var iconName: String
    var hourlyRate: Double
    var estimatedROI: Double
    var gitRepositoryPath: String = ""

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.project)
    var tasks: [TaskItem]

    @Relationship(deleteRule: .cascade, inverse: \TimeEntry.project)
    var timeEntries: [TimeEntry]

    @Relationship(deleteRule: .nullify, inverse: \Tag.projects)
    var tags: [Tag]

    init(
        name: String,
        projectDescription: String = "",
        category: ProjectCategory = .software,
        status: ProjectStatus = .planning,
        colorHex: String = "#007AFF",
        iconName: String = "folder.fill",
        hourlyRate: Double = 100,
        estimatedROI: Double = 0
    ) {
        self.syncId = UUID().uuidString
        self.updatedAt = Date()
        self.name = name
        self.projectDescription = projectDescription
        self.categoryRaw = category.rawValue
        self.statusRaw = status.rawValue
        self.createdAt = Date()
        self.completedAt = nil
        self.colorHex = colorHex
        self.iconName = iconName
        self.hourlyRate = hourlyRate
        self.estimatedROI = estimatedROI
        self.gitRepositoryPath = ""
        self.tasks = []
        self.timeEntries = []
        self.tags = []
    }

    var category: ProjectCategory {
        get { ProjectCategory(rawValue: categoryRaw) ?? .software }
        set { categoryRaw = newValue.rawValue }
    }

    var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRaw) ?? .planning }
        set {
            statusRaw = newValue.rawValue
            if newValue == .completed && completedAt == nil {
                completedAt = Date()
            }
        }
    }

    var totalSeconds: TimeInterval {
        let fromTasks = tasks.reduce(0) { $0 + $1.totalWorkedSeconds }
        let orphanEntries = timeEntries
            .filter { $0.task == nil }
            .reduce(0) { $0 + $1.duration }
        return fromTasks + orphanEntries
    }

    var investedValue: Double {
        (totalSeconds / 3600) * hourlyRate
    }

    var estimatedValue: Double {
        tasks.reduce(0) { $0 + ($1.estimatedSeconds / 3600) * hourlyRate }
    }

    var accumulatedValue: Double {
        investedValue
    }

    var hasGitRepository: Bool {
        !gitRepositoryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
