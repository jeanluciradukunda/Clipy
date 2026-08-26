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
        let config = Realm.Configuration(schemaVersion: 12, migrationBlock: { migration, oldSchemaVersion in
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
                // Schema 8: Added isPinned field to CPYClip
                migration.enumerateObjects(ofType: CPYClip.className()) { _, newObject in
                    newObject?["isPinned"] = false
                }
            }
            if oldSchemaVersion <= 8 {
                // Schema 9: Added isVault field to CPYFolder
                migration.enumerateObjects(ofType: CPYFolder.className()) { _, newObject in
                    newObject?["isVault"] = false
                }
            }
            if oldSchemaVersion <= 9 {
                // Schema 10: Added ocrText field to CPYClip
                migration.enumerateObjects(ofType: CPYClip.className()) { _, newObject in
                    newObject?["ocrText"] = nil
                }
            }
            if oldSchemaVersion <= 10 {
                // Schema 11: Added script snippet fields to CPYSnippet
                migration.enumerateObjects(ofType: CPYSnippet.className()) { _, newObject in
                    newObject?["snippetType"] = CPYSnippet.SnippetType.plainText.rawValue
                    newObject?["scriptShell"] = CPYSnippet.defaultShell
                    newObject?["scriptTimeout"] = CPYSnippet.defaultTimeout
                }
            }
            if oldSchemaVersion <= 11 {
                // Schema 12: Added isEphemeral field to CPYSnippet
                migration.enumerateObjects(ofType: CPYSnippet.className()) { _, newObject in
                    newObject?["isEphemeral"] = true
                }
            }
        })
        Realm.Configuration.defaultConfiguration = config
        do {
            _ = try Realm()
            logger.info("Realm migration completed successfully")
        } catch {
            logger.error("Realm migration failed: \(error.localizedDescription)")
        }
    }
}
