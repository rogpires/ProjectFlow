import Foundation

enum ProjectSortOption: String, CaseIterable, Identifiable {
    case alphabetical = "Ordem alfabética"
    case startDateNewest = "Início (mais recente)"
    case startDateOldest = "Início (mais antigo)"
    case status = "Status"
    case hoursWorked = "Horas trabalhadas"
    case investedValue = "Valor investido"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .alphabetical: "textformat.abc"
        case .startDateNewest, .startDateOldest: "calendar"
        case .status: "line.3.horizontal.decrease.circle"
        case .hoursWorked: "clock.fill"
        case .investedValue: "dollarsign.circle"
        }
    }

    func sort(_ projects: [Project]) -> [Project] {
        switch self {
        case .alphabetical:
            projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .startDateNewest:
            projects.sorted { $0.createdAt > $1.createdAt }
        case .startDateOldest:
            projects.sorted { $0.createdAt < $1.createdAt }
        case .status:
            projects.sorted { $0.statusRaw.localizedCompare($1.statusRaw) == .orderedAscending }
        case .hoursWorked:
            projects.sorted { $0.totalSeconds > $1.totalSeconds }
        case .investedValue:
            projects.sorted { $0.investedValue > $1.investedValue }
        }
    }
}

enum TaskSortOption: String, CaseIterable, Identifiable {
    case priority = "Prioridade"
    case alphabetical = "Ordem alfabética"
    case startDateNewest = "Início (mais recente)"
    case startDateOldest = "Início (mais antigo)"
    case hoursWorked = "Horas trabalhadas"
    case status = "Status"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .priority: "exclamationmark.triangle"
        case .alphabetical: "textformat.abc"
        case .startDateNewest, .startDateOldest: "calendar"
        case .hoursWorked: "clock.fill"
        case .status: "checkmark.circle"
        }
    }

    func sort(_ tasks: [TaskItem]) -> [TaskItem] {
        switch self {
        case .priority:
            tasks.sorted { $0.priority.sortOrder < $1.priority.sortOrder }
        case .alphabetical:
            tasks.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .startDateNewest:
            tasks.sorted { $0.createdAt > $1.createdAt }
        case .startDateOldest:
            tasks.sorted { $0.createdAt < $1.createdAt }
        case .hoursWorked:
            tasks.sorted { $0.actualSeconds > $1.actualSeconds }
        case .status:
            tasks.sorted { $0.statusRaw.localizedCompare($1.statusRaw) == .orderedAscending }
        }
    }
}
