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

                Text("Conecte ferramentas externas para sincronizar dados. A arquitetura está preparada para integrações futuras.")
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(IntegrationRegistry.available) { integration in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: integration.icon)
                                    .font(.title2)
                                    .foregroundStyle(Color.accentColor)
                                Text(integration.name)
                                    .font(.headline)
                                Spacer()
                                if integration.isAvailable {
                                    Text("Disponível")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.green.opacity(0.15), in: Capsule())
                                        .foregroundStyle(.green)
                                } else {
                                    Text("Em breve")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.secondary.opacity(0.15), in: Capsule())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(integration.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Conectar") {}
                                .buttonStyle(.bordered)
                                .disabled(!integration.isAvailable)
                        }
                        .padding(16)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Integrações")
    }
}
