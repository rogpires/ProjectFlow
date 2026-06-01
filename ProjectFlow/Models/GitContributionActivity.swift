//
//  GitContributionActivity.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import Foundation

struct GitContributionDay: Identifiable, Sendable {
    let date: Date
    let commitCount: Int

    var id: Date { date }
}

struct GitContributionWeek: Identifiable, Sendable {
    let id: Int
    /// Domingo … Sábado (sempre 7 posições); `nil` = fora do intervalo exibido.
    let days: [GitContributionDay?]

    init(id: Int, days: [GitContributionDay?]) {
        self.id = id
        if days.count == 7 {
            self.days = days
        } else {
            var padded = days
            while padded.count < 7 { padded.append(nil) }
            self.days = Array(padded.prefix(7))
        }
    }
}

struct GitMonthLabel: Identifiable, Sendable {
    let id: String
    let weekIndex: Int
    let label: String
}

struct GitContributionActivity: Sendable {
    let countsByDay: [Date: Int]
    let totalCommits: Int
    let weeks: [GitContributionWeek]
    let monthLabels: [GitMonthLabel]

    static let daysInRange = 371
    static let daysPerWeek = 7

    init(countsByDay: [Date: Int], calendar: Calendar = .current) {
        let normalized = Self.normalizeCounts(countsByDay, calendar: calendar)
        self.countsByDay = normalized
        self.totalCommits = normalized.values.reduce(0, +)

        let end = calendar.startOfDay(for: Date())
        guard let rangeStart = calendar.date(byAdding: .day, value: -(Self.daysInRange - 1), to: end) else {
            self.weeks = []
            self.monthLabels = []
            return
        }

        let alignedStart = Self.startOfWeek(containing: rangeStart, calendar: calendar)
        var builtWeeks: [GitContributionWeek] = []
        var weekStart = alignedStart
        var weekIndex = 0

        while weekStart <= end {
            var weekDays: [GitContributionDay?] = []
            weekDays.reserveCapacity(Self.daysPerWeek)

            for offset in 0..<Self.daysPerWeek {
                guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                    weekDays.append(nil)
                    continue
                }
                let dayStart = calendar.startOfDay(for: day)
                if dayStart < rangeStart || dayStart > end {
                    weekDays.append(nil)
                } else {
                    let count = normalized[dayStart] ?? 0
                    weekDays.append(GitContributionDay(date: dayStart, commitCount: count))
                }
            }

            builtWeeks.append(GitContributionWeek(id: weekIndex, days: weekDays))
            weekIndex += 1
            guard let next = calendar.date(byAdding: .day, value: 7, to: weekStart) else { break }
            weekStart = next
        }

        self.weeks = builtWeeks
        self.monthLabels = Self.buildMonthLabels(weeks: builtWeeks, calendar: calendar)
    }

    var maxDailyCommits: Int {
        countsByDay.values.max() ?? 0
    }

    private static func normalizeCounts(
                _ counts: [Date: Int],
        calendar: Calendar
    ) -> [Date: Int] {
        var normalized: [Date: Int] = [:]
        for (date, count) in counts {
            let day = calendar.startOfDay(for: date)
            normalized[day, default: 0] += count
        }
        return normalized
    }

    private static func startOfWeek(containing date: Date, calendar: Calendar) -> Date {
        var cal = calendar
        cal.firstWeekday = 1
        let dayStart = cal.startOfDay(for: date)
        let weekday = cal.component(.weekday, from: dayStart)
        let daysFromSunday = weekday - 1
        return cal.date(byAdding: .day, value: -daysFromSunday, to: dayStart) ?? dayStart
    }

    private static func buildMonthLabels(
        weeks: [GitContributionWeek],
        calendar: Calendar
    ) -> [GitMonthLabel] {
        var labels: [GitMonthLabel] = []
        var lastMonth: Int?

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "MMM"

        for (index, week) in weeks.enumerated() {
            var firstDate: Date?
            for slot in week.days {
                if let day = slot {
                    firstDate = day.date
                    break
                }
            }
            guard let firstDate else { continue }

            let month = calendar.component(.month, from: firstDate)
            if month != lastMonth {
                let label = formatter.string(from: firstDate).capitalized
                labels.append(GitMonthLabel(
                    id: "\(index)-\(month)",
                    weekIndex: index,
                    label: label
                ))
                lastMonth = month
            }
        }
        return labels
    }
}
