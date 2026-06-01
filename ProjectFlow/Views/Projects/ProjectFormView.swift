//
//  ProjectFormView.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import SwiftUI
import SwiftData
import AppKit

struct ProjectFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var project: Project?

    @State private var name = ""
    @State private var description = ""
    @State private var category: ProjectCategory = .software
    @State private var status: ProjectStatus = .planning
    @State private var colorHex = "#007AFF"
    @State private var iconName = "folder.fill"
    @State private var hourlyRate = 100.0
    @State private var estimatedROI = 0.0
    @State private var gitRepositoryPath = ""
    @State private var pendingRepositoryURL: URL?
    @State private var gitRepoIsValid: Bool?
    @State private var gitResolvedRoot: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Informações") {
                    TextField("Nome", text: $name)
                    TextField("Descrição", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    Picker("Categoria", selection: $category) {
                        ForEach(ProjectCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                    Picker("Status", selection: $status) {
                        ForEach(ProjectStatus.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                }

                Section("Aparência") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                        ForEach(ProjectColorPalette.colors, id: \.hex) { item in
                            Circle()
                                .fill(Color(hex: item.hex))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if colorHex == item.hex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { colorHex = item.hex }
                        }
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(ProjectIconPalette.icons, id: \.self) { icon in
                            Image(systemName: icon)
                                .frame(width: 32, height: 32)
                                .background(iconName == icon ? Color.accentColor.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 6))
                                .onTapGesture { iconName = icon }
                        }
                    }
                }

                Section("Financeiro") {
                    HStack {
                        Text("Valor hora")
                        Spacer()
                        TextField("100", value: $hourlyRate, format: .currency(code: "BRL"))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    HStack {
                        Text("ROI estimado")
                        Spacer()
                        TextField("0", value: $estimatedROI, format: .currency(code: "BRL"))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                }

                if GitKrakenSettings.isEnabled {
                    Section("GitKraken") {
                        HStack {
                            TextField("Caminho do repositório", text: $gitRepositoryPath)
                                .textFieldStyle(.roundedBorder)
                            Button("Escolher…") {
                                pickRepositoryFolder()
                            }
                        }
                        if !gitRepositoryPath.isEmpty {
                            if let gitRepoIsValid {
                                if gitRepoIsValid {
                                    Label("Repositório Git válido", systemImage: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                    if let gitResolvedRoot {
                                        Text(gitResolvedRoot)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                } else {
                                    Label("Pasta sem repositório Git — escolha a raiz do projeto (.git)", systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            } else {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .onChange(of: gitRepositoryPath) { _, newValue in
                validateGitRepository(path: newValue)
            }
            .navigationTitle(project == nil ? "Novo Projeto" : "Editar Projeto")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        Task { await save() }
                    }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                loadProject()
                validateGitRepository(path: gitRepositoryPath)
            }
            .frame(minWidth: 480, minHeight: 520)
        }
    }

    private func loadProject() {
        guard let project else { return }
        name = project.name
        description = project.projectDescription
        category = project.category
        status = project.status
        colorHex = project.colorHex
        iconName = project.iconName
        hourlyRate = project.hourlyRate
        estimatedROI = project.estimatedROI
        gitRepositoryPath = project.gitRepositoryPath
    }

    private func pickRepositoryFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Selecione a pasta do repositório Git"
        panel.prompt = "Selecionar"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        pendingRepositoryURL = url
        gitRepositoryPath = GitCommandRunner.repositoryRoot(at: url.path) ?? url.path
        if let project {
            _ = SyncIdentity.ensure(&project.syncId)
            GitRepositorySession.saveAccess(for: url, projectSyncId: project.syncId)
        }
        validateGitRepository(path: gitRepositoryPath)
    }

    private func validateGitRepository(path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            gitRepoIsValid = nil
            gitResolvedRoot = nil
            return
        }
        gitRepoIsValid = nil
        let syncId = project?.syncId
        Task {
            if let syncId, !syncId.isEmpty {
                let result = await GitRepositoryHelper.loadRepository(
                    storedPath: trimmed,
                    projectSyncId: syncId
                )
                await MainActor.run {
                    gitRepoIsValid = result.root != nil && result.errorMessage == nil
                    gitResolvedRoot = result.root
                }
            } else {
                let root = GitCommandRunner.repositoryRoot(at: trimmed)
                await MainActor.run {
                    gitRepoIsValid = root != nil
                    gitResolvedRoot = root
                }
            }
        }
    }

    private func applyGitRepository(to project: Project) async {
        let trimmed = gitRepositoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            project.gitRepositoryPath = ""
            if !project.syncId.isEmpty {
                RepositoryBookmarkStore.clear(projectSyncId: project.syncId)
            }
            return
        }
        _ = SyncIdentity.ensure(&project.syncId)
        let result = await GitRepositoryHelper.loadRepository(
            storedPath: trimmed,
            projectSyncId: project.syncId
        )
        project.gitRepositoryPath = result.root ?? trimmed
        if let url = pendingRepositoryURL {
            GitRepositorySession.saveAccess(for: url, projectSyncId: project.syncId)
        } else if let root = result.root {
            GitRepositorySession.saveAccess(
                for: URL(fileURLWithPath: root, isDirectory: true),
                projectSyncId: project.syncId
            )
        }
    }

    private func save() async {
        if let project {
            project.name = name
            project.projectDescription = description
            project.category = category
            project.status = status
            project.colorHex = colorHex
            project.iconName = iconName
            project.hourlyRate = hourlyRate
            project.estimatedROI = estimatedROI
            await applyGitRepository(to: project)
            SyncIdentity.touch(&project.updatedAt)
        } else {
            let newProject = Project(
                name: name,
                projectDescription: description,
                category: category,
                status: status,
                colorHex: colorHex,
                iconName: iconName,
                hourlyRate: hourlyRate,
                estimatedROI: estimatedROI
            )
            context.insert(newProject)
            _ = SyncIdentity.ensure(&newProject.syncId)
            await applyGitRepository(to: newProject)
            if let url = pendingRepositoryURL {
                GitRepositorySession.saveAccess(for: url, projectSyncId: newProject.syncId)
            }
            appState.activityLogger.log(
                action: .projectCreated,
                details: name,
                project: newProject,
                context: context
            )
            do {
                try context.save()
                appState.selectedProject = newProject
                appState.notifyDataChanged()
                dismiss()
            } catch {
                return
            }
            return
        }
        do {
            try context.save()
            appState.notifyDataChanged()
            dismiss()
        } catch {}
    }
}
