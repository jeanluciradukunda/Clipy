//
//  LegacyClipFolderMigration.swift
//
//  Clipy
//

import Foundation
import RealmSwift
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy", category: "LegacyClipFolder")

/// Before 2.2.1 the release build saved clip files in the Debug build's folder (`ClipyDev/`),
/// which the Debug build's clean-up deletes as orphans. Moves them into this build's own folder.
enum LegacyClipFolderMigration {

    static let legacyFolderName = "ClipyDev"

    struct Result: Equatable {
        var moved = 0
        var missing = 0
    }

    /// Copies each file first, commits the new paths, and only then deletes the originals.
    /// A no-op when `folder` is the legacy folder itself (the Debug build).
    @discardableResult
    static func relocate(in realm: Realm,
                         legacyFolder: String,
                         folder: String,
                         fileManager: FileManager = .default) -> Result {
        var result = Result()
        let legacy = URL(fileURLWithPath: legacyFolder).standardizedFileURL
        let target = URL(fileURLWithPath: folder).standardizedFileURL
        guard legacy.path != target.path else { return result }

        // Matched by folder name, so paths recorded under another home folder (Migration Assistant) still count
        let candidates = realm.objects(CPYClip.self)
            .filter("dataPath CONTAINS %@", "/\(legacyFolderName)/")
            .filter { URL(fileURLWithPath: $0.dataPath).deletingLastPathComponent().lastPathComponent == legacyFolderName }
        guard !candidates.isEmpty else { return result }
        try? fileManager.createDirectory(at: target, withIntermediateDirectories: true)

        var moves = [(hash: String, source: URL, destination: URL)]()
        for clip in candidates {
            let fileName = URL(fileURLWithPath: clip.dataPath).lastPathComponent
            let source = legacy.appendingPathComponent(fileName)
            guard fileManager.fileExists(atPath: source.path) else {
                result.missing += 1
                continue
            }
            var destination = target.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: destination.path) {
                destination = target.appendingPathComponent("\(UUID().uuidString).data")
            }
            do {
                try fileManager.copyItem(at: source, to: destination)
                moves.append((clip.dataHash, source, destination))
            } catch {
                logger.error("Could not copy \(fileName, privacy: .public): \(error.localizedDescription)")
            }
        }

        // Not `transaction`: it swallows a failed commit, and the originals must survive one
        do {
            try realm.write {
                for move in moves {
                    realm.object(ofType: CPYClip.self, forPrimaryKey: move.hash)?.dataPath = move.destination.path
                }
            }
        } catch {
            if realm.isInWriteTransaction { realm.cancelWrite() }
            logger.error("Could not record moved clip files: \(error.localizedDescription)")
            return result
        }
        for move in moves {
            try? fileManager.removeItem(at: move.source)
            result.moved += 1
        }
        if result.moved > 0 || result.missing > 0 {
            logger.info("Moved \(result.moved) clip file(s) out of \(legacyFolderName, privacy: .public); \(result.missing) already missing")
        }
        return result
    }
}
