//
//  RepositoryBookmarkStore.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import Foundation

enum RepositoryBookmarkStore {
    private static let keyPrefix = "ProjectFlow.repoBookmark."

    static func saveBookmark(for url: URL, projectSyncId: String) {
        guard let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(data, forKey: keyPrefix + projectSyncId)
    }

    static func resolveURL(projectSyncId: String) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: keyPrefix + projectSyncId) else {
            return nil
        }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        return url
    }

    static func clear(projectSyncId: String) {
        UserDefaults.standard.removeObject(forKey: keyPrefix + projectSyncId)
    }

    @discardableResult
    static func withSecurityScopedAccess<T>(
        projectSyncId: String,
        fallbackPath: String,
        _ work: (URL) -> T
    ) -> T? {
        if let url = resolveURL(projectSyncId: projectSyncId) {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            return work(url)
        }

        let expanded = (fallbackPath as NSString).expandingTildeInPath
        return work(URL(fileURLWithPath: expanded, isDirectory: true))
    }
}
