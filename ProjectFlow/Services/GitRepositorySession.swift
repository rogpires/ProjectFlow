//
//  GitRepositorySession.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import Foundation

struct GitRepositoryLoadResult: Sendable {
    var root: String?
    var counts: [Date: Int]
    var parsedCommitLines: Int
    var errorMessage: String?

    static let empty = GitRepositoryLoadResult(
        root: nil,
        counts: [:],
        parsedCommitLines: 0,
        errorMessage: nil
    )
}

/// Acesso com bookmark security-scoped ao repositório Git.
enum GitRepositorySession {
    private static let gitQueue = DispatchQueue(
        label: "com.rogeriocpires.ProjectFlow.git.session",
        qos: .utility
    )

    static func load(
        storedPath: String,
        projectSyncId: String
    ) async -> GitRepositoryLoadResult {
        await withCheckedContinuation { continuation in
            gitQueue.async {
                continuation.resume(returning: loadSync(
                    storedPath: storedPath,
                    projectSyncId: projectSyncId
                ))
            }
        }
    }

    private static func loadSync(
        storedPath: String,
        projectSyncId: String
    ) -> GitRepositoryLoadResult {
        let trimmed = storedPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return GitRepositoryLoadResult(
                root: nil,
                counts: [:],
                parsedCommitLines: 0,
                errorMessage: "Nenhuma pasta de repositório configurada."
            )
        }

        guard let scopedURL = resolveScopedURL(projectSyncId: projectSyncId, storedPath: trimmed) else {
            return GitRepositoryLoadResult(
                root: nil,
                counts: [:],
                parsedCommitLines: 0,
                errorMessage: "Sem permissão para a pasta. Edite o projeto e use \"Escolher…\" para selecionar o repositório novamente."
            )
        }

        let accessed = scopedURL.startAccessingSecurityScopedResource()
        defer {
            if accessed { scopedURL.stopAccessingSecurityScopedResource() }
        }

        guard let root = GitCommandRunner.repositoryRoot(at: scopedURL.path) else {
            return GitRepositoryLoadResult(
                root: nil,
                counts: [:],
                parsedCommitLines: 0,
                errorMessage: "A pasta selecionada não é um repositório Git válido."
            )
        }

        let sinceDays = GitContributionActivity.daysInRange + 14
        let logOutput = GitCommandRunner.run(
            arguments: [
                "log", "--all",
                "--since=\(sinceDays).days",
                "--pretty=format:%ct"
            ],
            workingDirectory: root
        )

        switch logOutput {
        case .failure(let message):
            return GitRepositoryLoadResult(
                root: root,
                counts: [:],
                parsedCommitLines: 0,
                errorMessage: message
            )
        case .success(let output):
            let countsResult = GitCommandRunner.aggregateCommitCounts(from: output)
            return GitRepositoryLoadResult(
                root: root,
                counts: countsResult.counts,
                parsedCommitLines: countsResult.parsed,
                errorMessage: countsResult.parsed == 0
                    ? "Nenhum commit encontrado. Faça um commit no repositório e toque em Atualizar."
                    : nil
            )
        }
    }

    private static func resolveScopedURL(projectSyncId: String, storedPath: String) -> URL? {
        RepositoryBookmarkStore.resolveURL(projectSyncId: projectSyncId)
    }

    /// Salva bookmark na raiz do Git (não só na subpasta escolhida).
    static func saveAccess(for pickedURL: URL, projectSyncId: String) {
        let path = pickedURL.path
        let root = GitCommandRunner.repositoryRoot(at: path) ?? path
        let rootURL = URL(fileURLWithPath: root, isDirectory: true)
        RepositoryBookmarkStore.saveBookmark(for: rootURL, projectSyncId: projectSyncId)
    }
}

enum GitCommandRunner {
    /// `/usr/bin/git` é um shim do xcrun e falha dentro do App Sandbox.
    private static let executableCandidates = [
        "/Applications/Xcode.app/Contents/Developer/usr/bin/git",
        "/Library/Developer/CommandLineTools/usr/bin/git",
        "/opt/homebrew/bin/git",
        "/usr/local/bin/git"
    ]

    private static let resolvedExecutablePath: String? = resolveExecutablePath()

    private static func resolveExecutablePath() -> String? {
        for path in executableCandidates where isUsableGit(at: path) {
            return path
        }
        return nil
    }

    private static func isUsableGit(at path: String) -> Bool {
        guard FileManager.default.isExecutableFile(atPath: path) else { return false }
        if isXcrunShim(at: path) { return false }
        return true
    }

    private static func isXcrunShim(at path: String) -> Bool {
        guard let handle = FileHandle(forReadingAtPath: path) else { return false }
        defer { try? handle.close() }
        let prefix = handle.readData(ofLength: 65_536)
        return prefix.range(of: Data("__xcrun_shim".utf8)) != nil
    }

    enum RunResult {
        case success(String)
        case failure(String)
    }

    static func repositoryRoot(at path: String) -> String? {
        switch run(arguments: ["rev-parse", "--show-toplevel"], workingDirectory: path) {
        case .success(let root) where !root.isEmpty:
            return root
        case .success, .failure:
            var isDirectory: ObjCBool = false
            let expanded = (path as NSString).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory),
                  isDirectory.boolValue,
                  FileManager.default.fileExists(atPath: expanded + "/.git") else {
                return nil
            }
            return expanded
        }
    }

    static func run(arguments: [String], workingDirectory: String) -> RunResult {
        guard let executablePath = resolvedExecutablePath else {
            return .failure(
                "Git não disponível no sandbox. Instale o Xcode ou as Command Line Tools (xcode-select --install)."
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
        process.arguments = arguments

        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["LC_ALL"] = "C"
        if executablePath.contains("Xcode.app") {
            let gitURL = URL(fileURLWithPath: executablePath)
            let developerDir = gitURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .path
            environment["DEVELOPER_DIR"] = developerDir
        }
        process.environment = environment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            return .failure("Não foi possível executar o Git: \(error.localizedDescription)")
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let stdout = String(decoding: outputData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = String(decoding: errorData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if process.terminationStatus == 0 {
            return .success(stdout)
        }

        if !stdout.isEmpty {
            return .success(stdout)
        }

        let detail = stderr.isEmpty ? "código \(process.terminationStatus)" : stderr
        return .failure("Git falhou (\(detail))")
    }

    struct CommitCountResult: Sendable {
        var counts: [Date: Int]
        var parsed: Int
    }

    static func aggregateCommitCounts(from logOutput: String) -> CommitCountResult {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(
            byAdding: .day,
            value: -GitContributionActivity.daysInRange,
            to: calendar.startOfDay(for: Date())
        ) else {
            return CommitCountResult(counts: [:], parsed: 0)
        }

        var counts: [Date: Int] = [:]
        var parsed = 0

        for lineSub in logOutput.split(separator: "\n", omittingEmptySubsequences: true) {
            let raw = String(lineSub).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty, let seconds = TimeInterval(raw) else { continue }
            parsed += 1
            let date = Date(timeIntervalSince1970: seconds)
            guard date >= cutoff else { continue }
            let day = calendar.startOfDay(for: date)
            counts[day, default: 0] += 1
        }

        return CommitCountResult(counts: counts, parsed: parsed)
    }
}
