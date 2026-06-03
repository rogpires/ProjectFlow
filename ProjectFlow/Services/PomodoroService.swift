//
//  PomodoroService.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import Foundation
import Observation

enum PomodoroPhase {
    case work
    case breakTime
    case idle
}

@MainActor
@Observable
final class PomodoroService {
    var phase: PomodoroPhase = .idle
    var mode: PomodoroMode = .classic
    var customWorkMinutes: Int = 25
    var customBreakMinutes: Int = 5
    var remainingSeconds: TimeInterval = 0
    var completedCycles: Int = 0
    var soundEnabled: Bool = true
    var currentProject: Project?
    var currentTask: TaskItem?
    var currentSession: PomodoroSession?

    private var tickTimer: Timer?

    var isActive: Bool { phase != .idle }

    var isTicking: Bool { tickTimer != nil }

    var workDuration: Int {
        mode == .custom ? customWorkMinutes : mode.workMinutes
    }

    var breakDuration: Int {
        mode == .custom ? customBreakMinutes : mode.breakMinutes
    }

    var displayTime: String {
        AppFormatters.formatDuration(remainingSeconds)
    }

    var phaseLabel: String {
        switch phase {
        case .work: "Foco"
        case .breakTime: "Pausa"
        case .idle: "Pronto"
        }
    }

    func start(project: Project? = nil, task: TaskItem? = nil) {
        currentProject = project
        currentTask = task
        phase = .work
        remainingSeconds = TimeInterval(workDuration * 60)
        currentSession = PomodoroSession(
            workMinutes: workDuration,
            breakMinutes: breakDuration,
            mode: mode,
            project: project,
            task: task
        )
        startTicking()
    }

    func pause() {
        stopTicking()
    }

    func resume() {
        if phase != .idle { startTicking() }
    }

    func stop() {
        stopTicking()
        phase = .idle
        remainingSeconds = 0
        currentSession = nil
    }

    func skipPhase() {
        advancePhase(completed: false)
    }

    private func startTicking() {
        stopTicking()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func tick() {
        guard remainingSeconds > 0 else {
            advancePhase(completed: true)
            return
        }
        remainingSeconds -= 1
    }

    private func advancePhase(completed: Bool) {
        switch phase {
        case .work:
            if completed {
                completedCycles += 1
                currentSession?.completedCycles = completedCycles
                NotificationService.shared.notify(
                    title: "Pomodoro concluído!",
                    body: "Hora da pausa de \(breakDuration) minutos.",
                    playSound: soundEnabled
                )
            }
            phase = .breakTime
            remainingSeconds = TimeInterval(breakDuration * 60)
        case .breakTime:
            if completed {
                NotificationService.shared.notify(
                    title: "Pausa encerrada",
                    body: "Hora de voltar ao foco!",
                    playSound: soundEnabled
                )
            }
            phase = .work
            remainingSeconds = TimeInterval(workDuration * 60)
        case .idle:
            break
        }
    }
}
