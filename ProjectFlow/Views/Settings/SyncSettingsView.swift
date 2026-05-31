import SwiftUI
import AppKit

struct SyncSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Sincronização iCloud")
                    .font(.largeTitle.bold())

                Text("Salve seus dados em uma pasta do iCloud Drive para usar o ProjectFlow em todos os seus MacBooks com o mesmo Apple ID.")
                    .foregroundStyle(.secondary)

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "icloud.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading) {
                                Text("Pasta iCloud")
                                    .font(.headline)
                                Text(appState.syncService.folderPath ?? "Nenhuma pasta selecionada")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            statusBadge
                        }

                        HStack(spacing: 12) {
                            Button("Escolher pasta…") {
                                pickFolder()
                            }
                            .buttonStyle(.borderedProminent)

                            if appState.syncService.isConfigured {
                                Button("Sincronizar agora") {
                                    Task { await appState.syncService.syncNow() }
                                }
                                .buttonStyle(.bordered)

                                Button("Desconectar") {
                                    appState.syncService.clearFolder()
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(4)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Como configurar")
                        .font(.headline)
                    Text("1. Crie uma pasta chamada **ProjectFlow** no iCloud Drive.")
                    Text("2. Clique em **Escolher pasta** e selecione essa pasta.")
                    Text("3. Repita nos outros MacBooks, selecionando a **mesma pasta**.")
                    Text("4. Aguarde o ícone de nuvem ficar sólido antes de abrir no outro Mac.")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if let remote = appState.syncService.remoteActiveTimer,
                   remote.deviceId != SyncDevice.id {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Timer ativo em outro Mac desde \(AppFormatters.dateTime.string(from: remote.startedAt)).")
                            .font(.caption)
                    }
                    .padding(12)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(24)
        }
        .navigationTitle("Sincronização")
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch appState.syncService.status {
        case .disabled:
            Text("Desativado")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.secondary.opacity(0.15), in: Capsule())
        case .idle:
            Text("Pronto")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.blue.opacity(0.15), in: Capsule())
        case .syncing:
            Text("Sincronizando…")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.orange.opacity(0.15), in: Capsule())
        case .synced(let date):
            Text("Sync \(AppFormatters.dateTime.string(from: date))")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.green.opacity(0.15), in: Capsule())
        case .error:
            Text("Erro")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.red.opacity(0.15), in: Capsule())
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Selecione a pasta ProjectFlow no iCloud Drive"
        panel.prompt = "Selecionar"

        if panel.runModal() == .OK, let url = panel.url {
            appState.syncService.configureFolder(url)
        }
    }
}
