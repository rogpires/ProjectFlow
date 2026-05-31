//
//  GoalPeriod.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import Foundation

enum GoalPeriod: String, Codable, CaseIterable, Identifiable {
    case daily = "Diária"
    case weekly = "Semanal"
    case monthly = "Mensal"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .daily: "sun.max"
        case .weekly: "calendar"
        case .monthly: "calendar.badge.clock"
        }
    }
}
