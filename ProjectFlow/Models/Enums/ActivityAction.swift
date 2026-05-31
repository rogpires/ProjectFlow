import Foundation

enum ActivityAction: String, Codable, CaseIterable, Identifiable {
    case timerStarted = "Timer iniciado"
    case timerPaused = "Timer pausado"
    case timerResumed = "Timer retomado"
    case timerStopped = "Timer encerrado"
    case pomodoroCompleted = "Pomodoro concluído"
    case projectCreated = "Projeto criado"
    case taskCreated = "Tarefa criada"
    case taskCompleted = "Tarefa concluída"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .timerStarted: "play.fill"
        case .timerPaused: "pause.fill"
        case .timerResumed: "play.fill"
        case .timerStopped: "stop.fill"
        case .pomodoroCompleted: "timer"
        case .projectCreated: "folder.badge.plus"
        case .taskCreated: "plus.circle"
        case .taskCompleted: "checkmark.circle.fill"
        }
    }
}
