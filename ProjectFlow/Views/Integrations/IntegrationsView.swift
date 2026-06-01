//
//  IntegrationsView.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import SwiftUI

struct IntegrationsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Integrações")
                    .font(.largeTitle.bold())

                Text("Conecte ferramentas externas para enriquecer seus projetos.")
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(IntegrationRegistry.available) { integration in
                        IntegrationCardView(integration: integration)
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Integrações")
    }
}

private struct IntegrationCardView: View {
    let integration: IntegrationDescriptor

    private var isAvailable: Bool {
        switch integration.id {
        case "gitkraken":
            true
        default:
            integration.isAvailable
        }
    }

    private var isConnected: Bool {
        switch integration.id {
        case "gitkraken":
            GitKrakenSettings.isEnabled && GitKrakenService.isInstalled
        default:
            integration.isConnected
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: integration.icon)
                    .font(.title2)
                    .foregroundStyle(integration.id == "gitkraken" ? .purple : Color.accentColor)
                Text(integration.name)
                    .font(.headline)
                Spacer()
                statusBadge
            }
            Text(integration.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            if integration.id == "gitkraken" {
                NavigationLink {
                    GitKrakenIntegrationView()
                } label: {
                    Text(isConnected ? "Configurar" : "Ativar")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Conectar") {}
                    .buttonStyle(.bordered)
                    .disabled(!isAvailable)
            }
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isConnected {
            Text("Ativo")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.green.opacity(0.15), in: Capsule())
                .foregroundStyle(.green)
        } else if isAvailable {
            Text("Disponível")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.blue.opacity(0.15), in: Capsule())
                .foregroundStyle(.blue)
        } else {
            Text("Em breve")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.secondary.opacity(0.15), in: Capsule())
                .foregroundStyle(.secondary)
        }
    }
}
