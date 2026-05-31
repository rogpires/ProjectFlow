import Foundation
import SwiftData

struct DashboardStats {
    var todayHours: TimeInterval = 0
    var todayActiveProjects: Int = 0
    var todayCompletedTasks: Int = 0
    var weekHours: TimeInterval = 0
    var weekDailyAverage: TimeInterval = 0
    var monthHours: TimeInterval = 0
    var monthDailyData: [(date: Date, hours: TimeInterval)] = []
}

struct ProjectMetrics {
    let project: Project
    let totalSeconds: TimeInterval
    let investedValue: Double
}

struct AdvancedMetrics {
    var totalByProject: [ProjectMetrics] = []
    var totalByCategory: [ProjectCategory: TimeInterval] = [:]
    var mostProductive: Project?
    var leastProductive: Project?
    var dailyAverage: TimeInterval = 0
    var weeklyAverage: TimeInterval = 0
    var mostProductiveHour: Int?
    var mostProductiveWeekday: Int?
}

@MainActor
enum MetricsService {
    static func totalSeconds(for entries: [TimeEntry], from start: Date, to end: Date) -> TimeInterval {
        entries.filter { entry in
            entry.startDate >= start && entry.startDate < end
        }.reduce(0) { $0 + $1.duration }
    }

    static func dashboardStats(entries: [TimeEntry], projects: [Project], tasks: [TaskItem]) -> DashboardStats {
        let entries = TimeEntryQueryHelper.displayEntries(entries)
        let now = Date()
        let todayStart = DateRangeHelper.startOfDay(now)
        let todayEnd = DateRangeHelper.endOfDay(now)
        let weekStart = DateRangeHelper.startOfWeek(now)
        let monthStart = DateRangeHelper.startOfMonth(now)

        let todayEntries = entries.filter { $0.startDate >= todayStart && $0.startDate < todayEnd }
        let weekEntries = entries.filter { $0.startDate >= weekStart }
        let monthEntries = entries.filter { $0.startDate >= monthStart }

        let todayHours = todayEntries.reduce(0) { $0 + $1.duration }
        let activeProjectIDs = Set(todayEntries.compactMap { $0.project?.persistentModelID })
        let todayCompleted = tasks.filter {
            guard let completedAt = $0.completedAt else { return false }
            return completedAt >= todayStart && completedAt < todayEnd
        }.count

        let weekHours = weekEntries.reduce(0) { $0 + $1.duration }
        let daysInWeek = max(1, Calendar.current.dateComponents([.day], from: weekStart, to: now).day ?? 1)

        let calendar = Calendar.current
        var monthData: [(date: Date, hours: TimeInterval)] = []
        var day = monthStart
        while day <= now {
            let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let dayHours = entries.filter { $0.startDate >= day && $0.startDate < next }
                .reduce(0) { $0 + $1.duration }
            monthData.append((date: day, hours: dayHours))
            day = next
        }

        return DashboardStats(
            todayHours: todayHours,
            todayActiveProjects: activeProjectIDs.count,
            todayCompletedTasks: todayCompleted,
            weekHours: weekHours,
            weekDailyAverage: weekHours / Double(daysInWeek),
            monthHours: monthEntries.reduce(0) { $0 + $1.duration },
            monthDailyData: monthData
        )
    }

    static func advancedMetrics(entries: [TimeEntry], projects: [Project]) -> AdvancedMetrics {
        let entries = TimeEntryQueryHelper.displayEntries(entries)
        var byProject: [ProjectMetrics] = projects.map { project in
            let seconds = project.totalSeconds
            return ProjectMetrics(project: project, totalSeconds: seconds, investedValue: project.investedValue)
        }.sorted { $0.totalSeconds > $1.totalSeconds }

        var byCategory: [ProjectCategory: TimeInterval] = [:]
        for project in projects {
            byCategory[project.category, default: 0] += project.totalSeconds
        }

        let activeProjects = byProject.filter { $0.totalSeconds > 0 }
        let most = activeProjects.first?.project
        let least = activeProjects.last?.project

        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentEntries = entries.filter { $0.startDate >= thirtyDaysAgo }
        let totalRecent = recentEntries.reduce(0) { $0 + $1.duration }
        let dailyAvg = totalRecent / 30

        let weekStart = DateRangeHelper.startOfWeek()
        let weekEntries = entries.filter { $0.startDate >= weekStart }
        let weekTotal = weekEntries.reduce(0) { $0 + $1.duration }

        var hourCounts = Array(repeating: 0.0, count: 24)
        for entry in entries {
            let hour = calendar.component(.hour, from: entry.startDate)
            hourCounts[hour] += entry.duration
        }
        let bestHour = hourCounts.enumerated().max(by: { $0.element < $1.element })?.offset

        var weekdayCounts = Array(repeating: 0.0, count: 7)
        for entry in entries {
            let weekday = calendar.component(.weekday, from: entry.startDate)
            weekdayCounts[weekday - 1] += entry.duration
        }
        let bestWeekday = weekdayCounts.enumerated().max(by: { $0.element < $1.element })?.offset

        return AdvancedMetrics(
            totalByProject: byProject,
            totalByCategory: byCategory,
            mostProductive: most,
            leastProductive: least,
            dailyAverage: dailyAvg,
            weeklyAverage: weekTotal,
            mostProductiveHour: bestHour,
            mostProductiveWeekday: bestWeekday
        )
    }

    static func goalProgress(goal: Goal, entries: [TimeEntry]) -> (current: TimeInterval, target: TimeInterval, progress: Double) {
        let now = Date()
        let start: Date
        switch goal.period {
        case .daily: start = DateRangeHelper.startOfDay(now)
        case .weekly: start = DateRangeHelper.startOfWeek(now)
        case .monthly: start = DateRangeHelper.startOfMonth(now)
        }
        let current = entries.filter { $0.startDate >= start }.reduce(0) { $0 + $1.duration }
        let target = goal.targetHours * 3600
        let progress = target > 0 ? min(current / target, 1.0) : 0
        return (current, target, progress)
    }

    static func tagStats(tags: [Tag]) -> [(tag: Tag, seconds: TimeInterval)] {
        tags.map { tag in
            let seconds = tag.timeEntries.reduce(0) { $0 + $1.duration }
            return (tag: tag, seconds: seconds)
        }.sorted { $0.seconds > $1.seconds }
    }

    static func projectValueMetrics(project: Project) -> (
        investedHours: TimeInterval,
        accumulatedValue: Double,
        totalTime: TimeInterval,
        dailyAverage: TimeInterval,
        estimatedROI: Double
    ) {
        let total = project.totalSeconds
        let daysSinceCreation = max(1, Calendar.current.dateComponents(
            [.day], from: project.createdAt, to: Date()
        ).day ?? 1)
        return (
            investedHours: total,
            accumulatedValue: project.investedValue,
            totalTime: total,
            dailyAverage: total / Double(daysSinceCreation),
            estimatedROI: project.estimatedROI
        )
    }
}
