//
//  RealmEncryptionService.swift
//
//  Clipy
//
//  Manages Realm database encryption using a Keychain-stored key.
//  On first launch, generates a 64-byte key and stores it in the Keychain.
//  Handles migration from unencrypted → encrypted for existing users.
//

import Foundation
import Security
import RealmSwift
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy", category: "Encryption")

final class RealmEncryptionService {
    static let shared = RealmEncryptionService()

    private let keychainAccount = "com.clipy-app.realm-encryption-key"
    private let keychainService = "Clipy"

    private init() {}

    /// Returns the 64-byte encryption key, creating and storing one if needed.
    func encryptionKey() -> Data {
        if let existing = loadKeyFromKeychain() {
            return existing
        }
        let newKey = generateKey()
        saveKeyToKeychain(newKey)
        return newKey
    }

    /// The actual Realm default file URL (resolved from Realm's own config)
    var defaultRealmURL: URL {
        Realm.Configuration.defaultConfiguration.fileURL
            ?? URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!)
                .appendingPathComponent("default.realm")
    }

    /// Check if an existing unencrypted database needs migration.
    /// Returns true if the database file exists AND no encryption key is in Keychain yet.
    var needsEncryptionMigration: Bool {
        let exists = FileManager.default.fileExists(atPath: defaultRealmURL.path)
        let hasKey = loadKeyFromKeychain() != nil
        return exists && !hasKey
    }

    /// Try to open Realm with encryption. If it fails (because the file is unencrypted),
    /// migrate to encrypted first.
    func migrateToEncryptedIfNeeded(config: Realm.Configuration) {
        let encryptedConfig = config
        // Try opening with encryption
        do {
            _ = try Realm(configuration: encryptedConfig)
            logger.info("Realm opened with encryption successfully")
        } catch {
            // Failed — likely unencrypted database. Attempt migration.
            logger.info("Encrypted open failed, attempting migration: \(error.localizedDescription)")
            migrateToEncrypted(encryptedConfig: encryptedConfig)
        }
    }

    // MARK: - Migration

    /// Migrate an existing unencrypted database to encrypted.
    private func migrateToEncrypted(encryptedConfig: Realm.Configuration) {
        guard let fileURL = encryptedConfig.fileURL else { return }
        let tempURL = fileURL.deletingLastPathComponent().appendingPathComponent("encrypted.realm")

        do {
            // Open old unencrypted database with same schema/migration
            var oldConfig = encryptedConfig
            oldConfig.encryptionKey = nil  // No encryption for old DB
            let oldRealm = try Realm(configuration: oldConfig)

            // Create new encrypted database at temp path
            var newConfig = encryptedConfig
            newConfig.fileURL = tempURL
            let newRealm = try Realm(configuration: newConfig)

            // Copy all data
            try newRealm.write {
                for clip in oldRealm.objects(CPYClip.self) {
                    let copy = CPYClip()
                    copy.dataPath = clip.dataPath
                    copy.title = clip.title
                    copy.dataHash = clip.dataHash
                    copy.primaryType = clip.primaryType
                    copy.updateTime = clip.updateTime
                    copy.thumbnailPath = clip.thumbnailPath
                    copy.isColorCode = clip.isColorCode
                    copy.isPinned = clip.isPinned
                    copy.ocrText = clip.ocrText
                    newRealm.add(copy, update: .all)
                }
                for folder in oldRealm.objects(CPYFolder.self) {
                    let copy = CPYFolder()
                    copy.index = folder.index
                    copy.enable = folder.enable
                    copy.title = folder.title
                    copy.identifier = folder.identifier
                    copy.isVault = folder.isVault
                    newRealm.add(copy, update: .all)

                    for snippet in folder.snippets {
                        let sCopy = CPYSnippet()
                        sCopy.index = snippet.index
                        sCopy.enable = snippet.enable
                        sCopy.title = snippet.title
                        sCopy.content = snippet.content
                        sCopy.identifier = snippet.identifier
                        newRealm.add(sCopy, update: .all)
                        copy.snippets.append(sCopy)
                    }
                }
            }

            oldRealm.invalidate()
            newRealm.invalidate()

            // Swap files
            let fm = FileManager.default
            let backupURL = fileURL.deletingLastPathComponent().appendingPathComponent("default.realm.unencrypted.bak")
            try fm.moveItem(at: fileURL, to: backupURL)
            try fm.moveItem(at: tempURL, to: fileURL)
            // Move auxiliary files
            for ext in [".lock", ".note", ".management"] {
                let tempAux = URL(fileURLWithPath: tempURL.path + ext)
                let destAux = URL(fileURLWithPath: fileURL.path + ext)
                try? fm.removeItem(at: destAux)
                try? fm.moveItem(at: tempAux, to: destAux)
            }

            logger.info("Successfully migrated to encrypted Realm")
        } catch {
            logger.error("Encryption migration failed: \(error.localizedDescription)")
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
        }
    }

    // MARK: - Key Generation

    private func generateKey() -> Data {
        var key = Data(count: 64)
        _ = key.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 64, $0.baseAddress!) }
        logger.info("Generated new Realm encryption key")
        return key
    }

    // MARK: - Keychain

    private func saveKeyToKeychain(_ key: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrService as String: keychainService,
            kSecValueData as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            logger.info("Encryption key saved to Keychain")
        } else {
            logger.error("Failed to save encryption key: \(status)")
        }
    }

    private func loadKeyFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, data.count == 64 else {
            return nil
        }
        return data
    }
}
