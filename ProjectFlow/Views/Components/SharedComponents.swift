//
//  SharedComponents.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct SectionHeader: View {
    let title: String
    var action: (() -> Void)?
    var actionLabel: String = "Adicionar"

    var body: some View {
        HStack {
            Text(title)
                .font(.title2.bold())
            Spacer()
            if let action {
                Button(actionLabel, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct ProjectBadge: View {
    let project: Project

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: project.iconName)
                .font(.caption)
            Text(project.name)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: project.colorHex).opacity(0.15), in: Capsule())
        .foregroundStyle(Color(hex: project.colorHex))
    }
}

struct TimerDisplay: View {
    let time: String
    let isRunning: Bool

    var body: some View {
        Text(time)
            .font(.system(size: 48, weight: .light, design: .monospaced))
            .foregroundStyle(isRunning ? .primary : .secondary)
            .contentTransition(.numericText())
            .animation(.default, value: time)
    }
}

struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)
        }
    }
}
