//
//  GitRepositoryHelper.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import Foundation

/// Fachada assíncrona — implementação em `GitRepositorySession`.
enum GitRepositoryHelper {
    static func resolveRepositoryRoot(
        from path: String,
        projectSyncId: String?
    ) async -> String? {
        guard let projectSyncId, !projectSyncId.isEmpty else {
            return GitCommandRunner.repositoryRoot(at: path)
        }
        let result = await GitRepositorySession.load(
            storedPath: path,
            projectSyncId: projectSyncId
        )
        return result.root
    }

    static func isValidGitRepository(at path: String, projectSyncId: String?) async -> Bool {
        await resolveRepositoryRoot(from: path, projectSyncId: projectSyncId) != nil
    }

    static func fetchDailyCommitCounts(
        at repositoryPath: String,
        projectSyncId: String? = nil
    ) async -> [Date: Int] {
        guard let projectSyncId, !projectSyncId.isEmpty else { return [:] }
        let result = await GitRepositorySession.load(
            storedPath: repositoryPath,
            projectSyncId: projectSyncId
        )
        return result.counts
    }

    static func loadRepository(
        storedPath: String,
        projectSyncId: String
    ) async -> GitRepositoryLoadResult {
        await GitRepositorySession.load(
            storedPath: storedPath,
            projectSyncId: projectSyncId
        )
    }
}
