//
//  ProjectStatusClockCard.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import SwiftUI

struct ProjectStatusClockCard: View {
    let project: Project
    let hoursToday: TimeInterval
    let isTimerRunning: Bool
    let liveTime: String?
    let staggerIndex: Int
    let animateEntrance: Bool
    let onOpen: () -> Void

    @State private var cardRevealed = false
    @State private var ringDrawProgress: Double = 0

    private var accent: Color { Color(hex: project.colorHex) }
    private var statusColor: Color { project.status.accentColor }

    private var targetRingProgress: Double {
        let estimatedSeconds = project.tasks.reduce(0) { $0 + $1.estimatedSeconds }
        if estimatedSeconds > 0 {
            return min(1, project.totalSeconds / estimatedSeconds)
        }
        let dayGoal: TimeInterval = 4 * 3600
        return min(1, hoursToday / dayGoal)
    }

    private var centerTime: String {
        if isTimerRunning, let liveTime { return liveTime }
        if hoursToday > 0 { return AppFormatters.formatHours(hoursToday) }
        return "00:00"
    }

    private var centerSubtitle: String {
        if isTimerRunning { return "AO VIVO" }
        if hoursToday > 0 { return "hoje" }
        return project.status.rawValue
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: project.iconName)
                        .font(.title3)
                        .foregroundStyle(accent)
                    Text(project.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                }

                ZStack {
                    ProgressRing(
                        progress: ringDrawProgress,
                        lineWidth: 6,
                        color: isTimerRunning ? accent : statusColor
                    )
                    .frame(width: 88, height: 88)

                    VStack(spacing: 2) {
                        Text(centerTime)
                            .font(.system(size: isTimerRunning ? 15 : 17, weight: .bold, design: .monospaced))
                            .contentTransition(.numericText())
                            .foregroundStyle(isTimerRunning ? accent : .primary)
                        Text(centerSubtitle)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(isTimerRunning ? accent : .secondary)
                            .tracking(0.6)
                    }
                    .opacity(cardRevealed ? 1 : 0)
                }
                .frame(height: 96)

                HStack(spacing: 6) {
                    Image(systemName: project.status.icon)
                        .font(.caption2)
                    Text(project.status.rawValue)
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.12), in: Capsule())
                .opacity(cardRevealed ? 1 : 0)
            }
            .padding(14)
            .frame(width: 168)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isTimerRunning ? accent.opacity(0.45) : statusColor.opacity(0.2),
                        lineWidth: isTimerRunning ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .opacity(cardRevealed ? 1 : 0)
        .offset(y: cardRevealed ? 0 : 18)
        .scaleEffect(cardRevealed ? 1 : 0.92)
        .onAppear { resetEntrance() }
        .onChange(of: animateEntrance) { _, shouldPlay in
            if shouldPlay {
                playEntrance()
            } else {
                resetEntrance()
            }
        }
        .onChange(of: targetRingProgress) { _, newValue in
            guard cardRevealed else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                ringDrawProgress = newValue
            }
        }
    }

    private func resetEntrance() {
        cardRevealed = false
        ringDrawProgress = 0
    }

    private func playEntrance() {
        resetEntrance()
        let delay = Double(staggerIndex) * 0.09
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(delay)) {
            cardRevealed = true
        }
        withAnimation(.easeOut(duration: 0.85).delay(delay + 0.05)) {
            ringDrawProgress = targetRingProgress
        }
    }
}
