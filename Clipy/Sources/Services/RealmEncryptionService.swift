//
//  RealmEncryptionService.swift
//
//  Clipy
//
//  Manages Realm database encryption using a Keychain-stored key.
//  On first launch, generates a 64-byte key and stores it in the Keychain.
//  On subsequent launches, retrieves the key to decrypt the database.
//  Handles migration from unencrypted → encrypted for existing users.
//

import Foundation
import Security
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

    /// Check if this is a fresh install (no existing unencrypted Realm database)
    var hasExistingUnencryptedDatabase: Bool {
        let defaultPath = defaultRealmPath
        let exists = FileManager.default.fileExists(atPath: defaultPath)
        let hasKey = loadKeyFromKeychain() != nil
        // If database exists but no key, it's unencrypted
        return exists && !hasKey
    }

    var defaultRealmPath: String {
        let directory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
            + "/com.clipy-app.Clipy"
        return directory + "/default.realm"
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
        // Delete existing if any
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
