//
//  Realm+Migration.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation
import RealmSwift
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy", category: "Migration")

extension Realm {
    static func migration() {
        let encryptionKey = RealmEncryptionService.shared.encryptionKey()

        // Handle migration from unencrypted → encrypted database
        if RealmEncryptionService.shared.hasExistingUnencryptedDatabase {
            migrateToEncrypted(encryptionKey: encryptionKey)
        }

        let config = Realm.Configuration(
            encryptionKey: encryptionKey,
            schemaVersion: 10,
            migrationBlock: { migration, oldSchemaVersion in
                if oldSchemaVersion <= 2 {
                    migration.enumerateObjects(ofType: CPYSnippet.className()) { _, newObject in
                        newObject?["identifier"] = NSUUID().uuidString
                    }
                }
                if oldSchemaVersion <= 4 {
                    migration.enumerateObjects(ofType: CPYFolder.className()) { _, newObject in
                        newObject?["identifier"] = NSUUID().uuidString
                    }
                }
                if oldSchemaVersion <= 5 {
                    migration.enumerateObjects(ofType: CPYClip.className(), { oldObject, newObject in
                        newObject?["dataPath"] = oldObject?["dataPath"]
                        newObject?["title"] = oldObject?["title"]
                        newObject?["dataHash"] = oldObject?["dataHash"]
                        newObject?["primaryType"] = oldObject?["primaryType"]
                        newObject?["updateTime"] = oldObject?["updateTime"]
                        newObject?["thumbnailPath"] = oldObject?["thumbnailPath"]
                    })
                    migration.enumerateObjects(ofType: CPYSnippet.className(), { oldObject, newObject in
                        newObject?["index"] = oldObject?["index"]
                        newObject?["enable"] = oldObject?["enable"]
                        newObject?["title"] = oldObject?["title"]
                        newObject?["content"] = oldObject?["content"]
                        if oldSchemaVersion >= 3 {
                            newObject?["identifier"] = oldObject?["identifier"]
                        }
                    })
                    migration.enumerateObjects(ofType: CPYFolder.className(), { oldObject, newObject in
                        newObject?["index"] = oldObject?["index"]
                        newObject?["enable"] = oldObject?["enable"]
                        newObject?["title"] = oldObject?["title"]
                        if oldSchemaVersion >= 5 {
                            newObject?["identifier"] = oldObject?["identifier"]
                        }
                    })
                }
                if oldSchemaVersion <= 7 {
                    migration.enumerateObjects(ofType: CPYClip.className()) { _, newObject in
                        newObject?["isPinned"] = false
                    }
                }
                if oldSchemaVersion <= 8 {
                    migration.enumerateObjects(ofType: CPYFolder.className()) { _, newObject in
                        newObject?["isVault"] = false
                    }
                }
                if oldSchemaVersion <= 9 {
                    migration.enumerateObjects(ofType: CPYClip.className()) { _, newObject in
                        newObject?["ocrText"] = nil
                    }
                }
            })
        Realm.Configuration.defaultConfiguration = config
        do {
            _ = try Realm()
            logger.info("Realm opened with encryption")
        } catch {
            logger.error("Realm migration failed: \(error.localizedDescription)")
        }
    }

    /// Migrate an existing unencrypted database to encrypted.
    /// Opens the old database without encryption, copies all data to a new encrypted one.
    private static func migrateToEncrypted(encryptionKey: Data) {
        logger.info("Migrating unencrypted Realm to encrypted")

        let defaultPath = RealmEncryptionService.shared.defaultRealmPath
        let tempPath = defaultPath + ".encrypted"

        do {
            // Open old unencrypted database
            let oldConfig = Realm.Configuration(
                schemaVersion: 10,
                migrationBlock: { _, _ in }
            )
            let oldRealm = try Realm(configuration: oldConfig)

            // Create new encrypted database
            var newConfig = Realm.Configuration(
                fileURL: URL(fileURLWithPath: tempPath),
                encryptionKey: encryptionKey,
                schemaVersion: 10
            )
            newConfig.objectTypes = [CPYClip.self, CPYFolder.self, CPYSnippet.self]
            let newRealm = try Realm(configuration: newConfig)

            // Copy all data
            try newRealm.write {
                for clip in oldRealm.objects(CPYClip.self) {
                    let newClip = CPYClip()
                    newClip.dataPath = clip.dataPath
                    newClip.title = clip.title
                    newClip.dataHash = clip.dataHash
                    newClip.primaryType = clip.primaryType
                    newClip.updateTime = clip.updateTime
                    newClip.thumbnailPath = clip.thumbnailPath
                    newClip.isColorCode = clip.isColorCode
                    newClip.isPinned = clip.isPinned
                    newClip.ocrText = clip.ocrText
                    newRealm.add(newClip, update: .all)
                }
                for folder in oldRealm.objects(CPYFolder.self) {
                    let newFolder = CPYFolder()
                    newFolder.index = folder.index
                    newFolder.enable = folder.enable
                    newFolder.title = folder.title
                    newFolder.identifier = folder.identifier
                    newFolder.isVault = folder.isVault
                    newRealm.add(newFolder, update: .all)

                    for snippet in folder.snippets {
                        let newSnippet = CPYSnippet()
                        newSnippet.index = snippet.index
                        newSnippet.enable = snippet.enable
                        newSnippet.title = snippet.title
                        newSnippet.content = snippet.content
                        newSnippet.identifier = snippet.identifier
                        newRealm.add(newSnippet, update: .all)
                        newFolder.snippets.append(newSnippet)
                    }
                }
            }

            // Close both
            oldRealm.invalidate()
            newRealm.invalidate()

            // Replace old with new
            let fm = FileManager.default
            try fm.removeItem(atPath: defaultPath)
            // Remove auxiliary Realm files
            for ext in [".lock", ".note", ".management"] {
                try? fm.removeItem(atPath: defaultPath + ext)
            }
            try fm.moveItem(atPath: tempPath, toPath: defaultPath)
            // Move auxiliary files
            for ext in [".lock", ".note", ".management"] {
                try? fm.moveItem(atPath: tempPath + ext, toPath: defaultPath + ext)
            }

            logger.info("Successfully migrated to encrypted Realm")
        } catch {
            logger.error("Encryption migration failed: \(error.localizedDescription)")
            // Clean up temp file
            try? FileManager.default.removeItem(atPath: tempPath)
        }
    }
}
