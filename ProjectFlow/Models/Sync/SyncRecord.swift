//
//  SyncRecord.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import Foundation

enum SyncIdentity {
    static func ensure(_ syncId: inout String) -> String {
        if syncId.isEmpty { syncId = UUID().uuidString }
        return syncId
    }

    static func touch(_ updatedAt: inout Date) {
        updatedAt = Date()
    }
}

enum SyncDevice {
    static var id: String {
        let key = "ProjectFlow.deviceId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }
}
