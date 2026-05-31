//
//  SidebarSection.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import Foundation

enum SidebarSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case projects = "Projetos"
    case timer = "Timer"
    case pomodoro = "Pomodoro"
    case reports = "Relatórios"
    case activity = "Histórico"
    case tags = "Tags"
    case goals = "Metas"
    case metrics = "Métricas"
    case projectValue = "Valor do Projeto"
    case sync = "Sincronização"
    case integrations = "Integrações"
    case about = "Sobre"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: "chart.bar.fill"
        case .projects: "folder.fill"
        case .timer: "timer"
        case .pomodoro: "clock.badge.checkmark"
        case .reports: "doc.text.fill"
        case .activity: "clock.arrow.circlepath"
        case .tags: "tag.fill"
        case .goals: "target"
        case .metrics: "chart.xyaxis.line"
        case .projectValue: "dollarsign.circle.fill"
        case .sync: "icloud.fill"
        case .integrations: "link"
        case .about: "info.circle.fill"
        }
    }
}
