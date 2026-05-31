//
//  TimeEntryQueryHelper.swift
//  ProjectFlow
//
//  Created by Rogerio Pires on 30/05/26.
//

import Foundation
import SwiftData

enum TimeEntryQueryHelper {
    static func uniqueByID<T: PersistentModel>(_ items: [T]) -> [T] {
        var seen = Set<PersistentIdentifier>()
        return items.filter { seen.insert($0.persistentModelID).inserted }
    }

    static func fingerprint(_ entry: TimeEntry) -> String {
        let projectKey = entry.project.map { String(describing: $0.persistentModelID) } ?? "none"
        let taskKey = entry.task.map { String(describing: $0.persistentModelID) } ?? "none"
        let minute = Int(entry.startDate.timeIntervalSince1970 / 60)
        return "\(projectKey)|\(taskKey)|\(minute)"
    }

    /// Remove duplicatas por ID e por conteúdo (mesmo projeto, tarefa e minuto).
    static func displayEntries(_ entries: [TimeEntry]) -> [TimeEntry] {
        let unique = uniqueByID(entries)
        var bestByFingerprint: [String: TimeEntry] = [:]

        for entry in unique where entry.duration >= 1 {
            let key = fingerprint(entry)
            if let existing = bestByFingerprint[key] {
                if entry.duration > existing.duration {
                    bestByFingerprint[key] = entry
                }
            } else {
                bestByFingerprint[key] = entry
            }
        }

        return bestByFingerprint.values.sorted { $0.startDate > $1.startDate }
    }
}

@MainActor
enum TimeEntryCleanupService {
    /// Remove registros duplicados e sessões vazias persistidas antes da correção do timer.
    static func cleanupDuplicates(in context: ModelContext) {
        let descriptor = FetchDescriptor<TimeEntry>(
            sortBy: [SortDescriptor(\.startDate)]
        )
        guard let entries = try? context.fetch(descriptor) else { return }

        var bestByFingerprint: [String: TimeEntry] = [:]
        var toDelete: [TimeEntry] = []

        for entry in entries {
            if entry.duration < 1 {
                toDelete.append(entry)
                continue
            }

            let key = TimeEntryQueryHelper.fingerprint(entry)
            if let existing = bestByFingerprint[key] {
                if entry.duration > existing.duration {
                    toDelete.append(existing)
                    bestByFingerprint[key] = entry
                } else {
                    toDelete.append(entry)
                }
            } else {
                bestByFingerprint[key] = entry
            }
        }

        for entry in toDelete {
            context.delete(entry)
        }

        if !toDelete.isEmpty {
            try? context.save()
        }
    }
}
