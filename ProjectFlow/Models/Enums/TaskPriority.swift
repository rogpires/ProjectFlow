//
//  TaskPriority.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import Foundation

enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case low = "Baixa"
    case medium = "Média"
    case high = "Alta"
    case urgent = "Urgente"

    var id: String { rawValue }

    var sortOrder: Int {
        switch self {
        case .urgent: 0
        case .high: 1
        case .medium: 2
        case .low: 3
        }
    }
}
