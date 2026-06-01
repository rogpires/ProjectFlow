//
//  GitKrakenService.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import AppKit
import Foundation

enum GitKrakenError: LocalizedError {
    case notInstalled
    case invalidRepository
    case openFailed(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            "GitKraken não está instalado. Baixe em gitkraken.com e instale em /Applications."
        case .invalidRepository:
            "O caminho informado não é um repositório Git válido."
        case .openFailed(let detail):
            "Não foi possível abrir o GitKraken: \(detail)"
        }
    }
}

@MainActor
enum GitKrakenService {
    private static let appName = "GitKraken"
    private static let bundleIdentifiers = [
        "com.axosoft.gitkraken",
        "com.gitkraken.GitKraken"
    ]

    static var isInstalled: Bool {
        applicationURL != nil
    }

    static var applicationURL: URL? {
        let applications = URL(fileURLWithPath: "/Applications/\(appName).app")
        if FileManager.default.fileExists(atPath: applications.path) {
            return applications
        }
        for identifier in bundleIdentifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
                return url
            }
        }
        return nil
    }

    static func openRepository(at path: String, projectSyncId: String? = nil) async throws {
        guard isInstalled else { throw GitKrakenError.notInstalled }

        let resolvedPath = await resolveRepositoryPath(path: path, projectSyncId: projectSyncId)

        guard let resolvedPath, !resolvedPath.isEmpty else {
            throw GitKrakenError.invalidRepository
        }

        if openWithURLScheme(at: resolvedPath) { return }
        if await openWithApplication(at: resolvedPath) { return }
        throw GitKrakenError.openFailed("Tente abrir o repositório manualmente no GitKraken.")
    }

    private static func resolveRepositoryPath(path: String, projectSyncId: String?) async -> String? {
        guard let projectSyncId, !projectSyncId.isEmpty else {
            return GitCommandRunner.repositoryRoot(at: path)
        }
        let result = await GitRepositorySession.load(
            storedPath: path,
            projectSyncId: projectSyncId
        )
        return result.root
    }

    private static func openWithApplication(at path: String) async -> Bool {
        guard let appURL = applicationURL else { return false }

        let config = NSWorkspace.OpenConfiguration()
        config.arguments = ["-p", path]
        config.createsNewApplicationInstance = true

        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
                continuation.resume(returning: error == nil)
            }
        }
    }

    private static func openWithURLScheme(at path: String) -> Bool {
        guard let encoded = path.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed.union(CharacterSet(charactersIn: "/"))
        ),
        let url = URL(string: "gitkraken://repo/\(encoded)") else {
            return false
        }
        return NSWorkspace.shared.open(url)
    }
}
