//
//  SyncPayload.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import Foundation

struct SyncPackage: Codable {
    var revision: Int
    var exportedAt: Date
    var deviceId: String
    var deletedSyncIds: [String]
    var activeTimer: ActiveTimerDTO?
    var projects: [ProjectDTO]
    var tasks: [TaskDTO]
    var timeEntries: [TimeEntryDTO]
    var tags: [TagDTO]
    var activityLogs: [ActivityLogDTO]
    var goals: [GoalDTO]
    var pomodoroSessions: [PomodoroSessionDTO]
}

struct ActiveTimerDTO: Codable {
    var deviceId: String
    var projectSyncId: String
    var taskSyncId: String
    var startedAt: Date
    var state: String
}

struct ProjectDTO: Codable {
    var syncId: String
    var updatedAt: Date
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
    var tagSyncIds: [String]
}

struct TaskDTO: Codable {
    var syncId: String
    var updatedAt: Date
    var projectSyncId: String
    var name: String
    var taskDescription: String
    var priorityRaw: String
    var statusRaw: String
    var estimatedSeconds: TimeInterval
    var manualWorkedSeconds: TimeInterval?
    var actualSeconds: TimeInterval
    var createdAt: Date
    var completedAt: Date?
}

struct TimeEntryDTO: Codable {
    var syncId: String
    var updatedAt: Date
    var projectSyncId: String
    var taskSyncId: String
    var startDate: Date
    var endDate: Date?
    var notes: String
    var isRunning: Bool
    var tagSyncIds: [String]
}

struct TagDTO: Codable {
    var syncId: String
    var updatedAt: Date
    var name: String
    var colorHex: String
    var createdAt: Date
}

struct ActivityLogDTO: Codable {
    var syncId: String
    var updatedAt: Date
    var timestamp: Date
    var actionRaw: String
    var details: String
    var projectName: String?
    var taskName: String?
}

struct GoalDTO: Codable {
    var syncId: String
    var updatedAt: Date
    var title: String
    var targetHours: Double
    var periodRaw: String
    var createdAt: Date
    var isActive: Bool
}

struct PomodoroSessionDTO: Codable {
    var syncId: String
    var updatedAt: Date
    var startDate: Date
    var endDate: Date?
    var workMinutes: Int
    var breakMinutes: Int
    var completedCycles: Int
    var isWorkPhase: Bool
    var modeRaw: String
    var projectSyncId: String?
    var taskSyncId: String?
}
