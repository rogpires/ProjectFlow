import Foundation

enum ProjectStatus: String, Codable, CaseIterable, Identifiable {
    case planning = "Planejamento"
    case inProgress = "Em andamento"
    case paused = "Pausado"
    case completed = "Finalizado"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .planning: "list.bullet.clipboard"
        case .inProgress: "play.circle"
        case .paused: "pause.circle"
        case .completed: "checkmark.circle"
        }
    }
}
