//
//  VaultAuthService.swift
//
//  Clipy Dev
//
//  Provides Touch ID / password authentication for vault snippet folders.
//

import Foundation
import LocalAuthentication
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy-Dev", category: "VaultAuth")

@MainActor
final class VaultAuthService {
    static let shared = VaultAuthService()

    /// Folder IDs that have been unlocked this session
    private var unlockedFolderIDs = Set<String>()

    private init() {}

    func isUnlocked(_ folderID: String) -> Bool {
        unlockedFolderIDs.contains(folderID)
    }

    func lockAll() {
        unlockedFolderIDs.removeAll()
    }

    func lock(_ folderID: String) {
        unlockedFolderIDs.remove(folderID)
    }

    /// Authenticate to unlock a vault folder. Calls completion on main thread.
    func authenticate(folderID: String, reason: String = "Unlock vault folder", completion: @escaping (Bool) -> Void) {
        if unlockedFolderIDs.contains(folderID) {
            completion(true)
            return
        }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            logger.error("Biometric auth not available: \(error?.localizedDescription ?? "unknown")")
            completion(false)
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] success, authError in
            DispatchQueue.main.async {
                if success {
                    self?.unlockedFolderIDs.insert(folderID)
                    logger.info("Vault folder unlocked: \(folderID)")
                    completion(true)
                } else {
                    logger.info("Vault auth failed: \(authError?.localizedDescription ?? "cancelled")")
                    completion(false)
                }
            }
        }
    }
}
