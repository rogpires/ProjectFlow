//
//  TaskStatus.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import Foundation

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case todo = "A fazer"
    case inProgress = "Em andamento"
    case completed = "Concluída"
    case cancelled = "Cancelada"

    var id: String { rawValue }
}
