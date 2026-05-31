//
//  ProjectCategory.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import Foundation

enum ProjectCategory: String, Codable, CaseIterable, Identifiable {
    case software = "Software"
    case hardware = "Hardware"
    case firmware = "Firmware"
    case research = "Pesquisa"
    case client = "Cliente"
    case personal = "Pessoal"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .software: "laptopcomputer"
        case .hardware: "cpu"
        case .firmware: "memorychip"
        case .research: "magnifyingglass"
        case .client: "person.2"
        case .personal: "house"
        }
    }
}
