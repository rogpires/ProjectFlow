//
//  GitContributionHeatmapView.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import SwiftUI

struct GitContributionHeatmapView: View {
    let activity: GitContributionActivity
    var accentColor: Color = .green

    @State private var hoveredDayID: Date?

    private let cellSize: CGFloat = 11
    private let cellSpacing: CGFloat = 3
    private let weekdayLabels = ["", "Seg", "", "Qua", "", "Sex", ""]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(activity.totalCommits) commits no último ano")
                .font(.subheadline.weight(.medium))

            monthLabelRow

            HStack(alignment: .top, spacing: 8) {
                weekdayColumn
                    .padding(.top, 22)
                weeksGrid
                    .padding(.top, 22)
            }

            legend
        }
    }

    private var monthLabelRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Color.clear
                .frame(width: 28)
            ZStack(alignment: .topLeading) {
                Color.clear
                    .frame(
                        width: gridWidth,
                        height: 14
                    )
                ForEach(activity.monthLabels) { item in
                    Text(item.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .offset(x: CGFloat(item.weekIndex) * (cellSize + cellSpacing))
                }
            }
        }
    }

    private var weekdayColumn: some View {
        VStack(alignment: .trailing, spacing: cellSpacing) {
            ForEach(0..<GitContributionActivity.daysPerWeek, id: \.self) { row in
                Text(weekdayLabels.indices.contains(row) ? weekdayLabels[row] : "")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: cellSize, alignment: .trailing)
            }
        }
    }

    private var weeksGrid: some View {
        HStack(alignment: .top, spacing: cellSpacing) {
            ForEach(activity.weeks) { week in
                VStack(spacing: cellSpacing) {
                    ForEach(0..<GitContributionActivity.daysPerWeek, id: \.self) { row in
                        cellView(dayAt(row: row, in: week))
                    }
                }
            }
        }
    }

    private func dayAt(row: Int, in week: GitContributionWeek) -> GitContributionDay? {
        guard row >= 0, row < week.days.count else { return nil }
        return week.days[row]
    }

    @ViewBuilder
    private func cellView(_ day: GitContributionDay?) -> some View {
        if let day {
            RoundedRectangle(cornerRadius: 2)
                .fill(color(for: day.commitCount))
                .frame(width: cellSize, height: cellSize)
                .contentShape(Rectangle())
                .onHover { isHovered in
                    if isHovered {
                        hoveredDayID = day.id
                    } else if hoveredDayID == day.id {
                        hoveredDayID = nil
                    }
                }
                .overlay(alignment: .top) {
                    if hoveredDayID == day.id {
                        dayTooltip(for: day)
                            .fixedSize()
                            .offset(y: -30)
                            .zIndex(100)
                    }
                }
                .help(helpText(for: day))
        } else {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.clear)
                .frame(width: cellSize, height: cellSize)
        }
    }

    private func dayTooltip(for day: GitContributionDay) -> some View {
        Text(helpText(for: day))
            .font(.caption)
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.quaternary, lineWidth: 1)
            }
            .allowsHitTesting(false)
    }

    private var legend: some View {
        HStack {
            Spacer()
            Text("Menos")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(forLevel: level))
                        .frame(width: 11, height: 11)
                }
            }
            Text("Mais")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var gridWidth: CGFloat {
        CGFloat(activity.weeks.count) * (cellSize + cellSpacing) - cellSpacing
    }

    private func color(for count: Int) -> Color {
        if count == 0 { return Color.primary.opacity(0.08) }
        let max = max(activity.maxDailyCommits, 1)
        let ratio = Double(count) / Double(max)
        let level: Int
        switch ratio {
        case ..<0.25: level = 1
        case ..<0.5: level = 2
        case ..<0.75: level = 3
        default: level = 4
        }
        return color(forLevel: level)
    }

    private func color(forLevel level: Int) -> Color {
        switch level {
        case 0: Color.primary.opacity(0.08)
        case 1: accentColor.opacity(0.45)
        case 2: accentColor.opacity(0.65)
        case 3: accentColor.opacity(0.85)
        default: accentColor
        }
    }

    private func helpText(for day: GitContributionDay) -> String {
        let count = day.commitCount
        let commits: String
        switch count {
        case 0: commits = "Nenhum commit"
        case 1: commits = "1 commit"
        default: commits = "\(count) commits"
        }
        let date = AppFormatters.shortDate.string(from: day.date)
        return "\(commits) · \(date)"
    }
}

#Preview {
    GitContributionHeatmapView(activity: .previewSample)
        .padding()
        .frame(width: 800)
}

@MainActor
private extension GitContributionActivity {
    static var previewSample: GitContributionActivity {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var counts: [Date: Int] = [:]
        for offset in 0..<120 {
            if let day = calendar.date(byAdding: .day, value: -offset, to: today) {
                counts[day] = Int.random(in: 0...8)
            }
        }
        return GitContributionActivity(countsByDay: counts)
    }
}
