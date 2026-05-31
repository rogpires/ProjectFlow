//
//  PomodoroMode.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import Foundation

enum PomodoroMode: String, Codable, CaseIterable, Identifiable {
    case classic = "25/5"
    case extended = "50/10"
    case custom = "Personalizado"

    var id: String { rawValue }

    var workMinutes: Int {
        switch self {
        case .classic: 25
        case .extended: 50
        case .custom: 25
        }
    }

    var breakMinutes: Int {
        switch self {
        case .classic: 5
        case .extended: 10
        case .custom: 5
        }
    }
}
