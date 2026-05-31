//
//  IntegrationProvider.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import Foundation

/// Protocolo base para integrações futuras (GitHub, GitLab, CloudKit, etc.)
protocol IntegrationProvider: Sendable {
    var name: String { get }
    var icon: String { get }
    var isConnected: Bool { get }
    func connect() async throws
    func disconnect() async throws
    func sync() async throws
}

struct IntegrationDescriptor: Identifiable, Sendable {
    let id: String
    let name: String
    let icon: String
    let description: String
    var isConnected: Bool
    var isAvailable: Bool
}

enum IntegrationRegistry {
    static let available: [IntegrationDescriptor] = [
        IntegrationDescriptor(
            id: "github",
            name: "GitHub",
            icon: "chevron.left.forwardslash.chevron.right",
            description: "Sincronize commits e issues com projetos.",
            isConnected: false,
            isAvailable: false
        ),
        IntegrationDescriptor(
            id: "gitlab",
            name: "GitLab",
            icon: "server.rack",
            description: "Conecte repositórios e pipelines.",
            isConnected: false,
            isAvailable: false
        ),
        IntegrationDescriptor(
            id: "gitkraken",
            name: "GitKraken",
            icon: "arrow.triangle.branch",
            description: "Integração com fluxo Git visual.",
            isConnected: false,
            isAvailable: false
        ),
        IntegrationDescriptor(
            id: "pocketbase",
            name: "PocketBase",
            icon: "cylinder.split.1x2",
            description: "Backend self-hosted para sync.",
            isConnected: false,
            isAvailable: false
        ),
        IntegrationDescriptor(
            id: "cloudkit",
            name: "CloudKit",
            icon: "icloud",
            description: "Sincronização via iCloud.",
            isConnected: false,
            isAvailable: false
        )
    ]
}
