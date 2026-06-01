//
//  ProjectStatus.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

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

    var isActive: Bool {
        self == .planning || self == .inProgress
    }
}

/// Filtro da lista de projetos (agrupa ativos, pausados e finalizados).
enum ProjectListFilter: String, CaseIterable, Identifiable {
    case all = "Todos"
    case active = "Ativos"
    case paused = "Pausados"
    case completed = "Finalizados"

    var id: String { rawValue }

    var sectionTitle: String {
        switch self {
        case .all: "Projetos"
        case .active: "Ativos"
        case .paused: "Pausados"
        case .completed: "Finalizados"
        }
    }

    var sectionIcon: String {
        switch self {
        case .all: "folder"
        case .active: "play.circle"
        case .paused: "pause.circle"
        case .completed: "checkmark.circle"
        }
    }

    func includes(_ status: ProjectStatus) -> Bool {
        switch self {
        case .all: true
        case .active: status.isActive
        case .paused: status == .paused
        case .completed: status == .completed
        }
    }
}
