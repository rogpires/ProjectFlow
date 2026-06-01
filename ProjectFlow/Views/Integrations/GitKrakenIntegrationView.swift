//
//  GitKrakenIntegrationView.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import SwiftUI
import SwiftData

struct GitKrakenIntegrationView: View {
    @Query(sort: \Project.name) private var projects: [Project]

    @State private var isEnabled = GitKrakenSettings.isEnabled
    @State private var openError: String?

    private var linkedProjects: [Project] {
        projects.filter(\.hasGitRepository)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                statusCard
                settingsCard
                linkedProjectsSection
                helpSection
            }
            .padding(24)
        }
        .navigationTitle("GitKraken")
        .alert("GitKraken", isPresented: .init(
            get: { openError != nil },
            set: { if !$0 { openError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(openError ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.largeTitle)
                    .foregroundStyle(.purple)
                VStack(alignment: .leading) {
                    Text("GitKraken")
                        .font(.title.bold())
                    Text("Abra repositórios Git dos seus projetos direto no GitKraken.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var statusCard: some View {
        GroupBox {
            HStack {
                Image(systemName: GitKrakenService.isInstalled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(GitKrakenService.isInstalled ? .green : .orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(GitKrakenService.isInstalled ? "GitKraken instalado" : "GitKraken não encontrado")
                        .font(.headline)
                    if GitKrakenService.isInstalled, let url = GitKrakenService.applicationURL {
                        Text(url.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("Instale o GitKraken Desktop em /Applications.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !GitKrakenService.isInstalled {
                    Button("Baixar") {
                        NSWorkspace.shared.open(URL(string: "https://www.gitkraken.com/download")!)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(4)
        }
    }

    private var settingsCard: some View {
        GroupBox("Configuração") {
            Toggle("Integração ativa", isOn: $isEnabled)
                .onChange(of: isEnabled) { _, value in
                    GitKrakenSettings.isEnabled = value
                }
            Text("Quando ativa, projetos com pasta Git vinculada exibem atalho para abrir no GitKraken e commits recentes.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var linkedProjectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projetos vinculados")
                .font(.headline)

            if linkedProjects.isEmpty {
                Text("Nenhum projeto com repositório Git. Edite um projeto e escolha a pasta do repositório na seção GitKraken.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(linkedProjects, id: \.persistentModelID) { project in
                    HStack {
                        Image(systemName: project.iconName)
                            .foregroundStyle(Color(hex: project.colorHex))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.name)
                                .font(.subheadline.weight(.medium))
                            Text(project.gitRepositoryPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button("Abrir") {
                            openProject(project)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!GitKrakenService.isInstalled || !isEnabled)
                    }
                    .padding(12)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Como usar")
                .font(.headline)
            Text("1. Em **Projetos**, edite um projeto e escolha a pasta do repositório Git.")
            Text("2. No detalhe do projeto, use **Abrir no GitKraken** ou veja os commits recentes.")
            Text("3. A pasta precisa ser escolhida pelo seletor de arquivos para o app ter permissão de leitura (sandbox).")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private func openProject(_ project: Project) {
        guard isEnabled else { return }
        let path = project.gitRepositoryPath
        let syncId = project.syncId
        Task {
            do {
                _ = SyncIdentity.ensure(&project.syncId)
                try await GitKrakenService.openRepository(at: path, projectSyncId: syncId)
            } catch {
                await MainActor.run {
                    openError = error.localizedDescription
                }
            }
        }
    }
}
