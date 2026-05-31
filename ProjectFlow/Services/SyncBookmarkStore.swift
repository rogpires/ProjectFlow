//
//  SyncBookmarkStore.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import Foundation

enum SyncBookmarkStore {
    private static let bookmarkKey = "ProjectFlow.iCloudFolderBookmark"
    private static let folderNameKey = "ProjectFlow.iCloudFolderName"

    static var folderDisplayName: String? {
        UserDefaults.standard.string(forKey: folderNameKey)
    }

    static func saveBookmark(for url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        if let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(data, forKey: bookmarkKey)
            UserDefaults.standard.set(url.path, forKey: folderNameKey)
        }
    }

    static func resolveFolderURL() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        if stale, let refreshed = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(refreshed, forKey: bookmarkKey)
        }
        return url
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: folderNameKey)
    }

    static var isConfigured: Bool {
        resolveFolderURL() != nil
    }
}
