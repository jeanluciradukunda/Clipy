//
//  VaultAuthService.swift
//
//  Clipy
//
//  Provides Touch ID / password authentication for vault snippet folders.
//

import Foundation
import LocalAuthentication
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy", category: "VaultAuth")

@MainActor
final class VaultAuthService {
    static let shared = VaultAuthService()

    /// Folder IDs that have been unlocked this session
    private var unlockedFolderIDs = Set<String>()

    /// Asks the device owner to authenticate; tests replace it to avoid a real Touch ID prompt.
    var evaluate: (_ reason: String, _ completion: @escaping (Bool) -> Void) -> Void = VaultAuthService.evaluateDeviceOwner

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

    /// Authenticate to unlock a vault folder. Calls completion on main thread. `force` asks again even when the
    /// folder is already unlocked this session, for actions that remove protection.
    func authenticate(folderID: String, reason: String = "Unlock vault folder", force: Bool = false, completion: @escaping (Bool) -> Void) {
        if !force && unlockedFolderIDs.contains(folderID) {
            completion(true)
            return
        }
        evaluate(reason) { [weak self] success in
            if success {
                UsageMetricsService.shared.track(.vaultUnlocked)
                self?.unlockedFolderIDs.insert(folderID)
                logger.info("Vault folder unlocked: \(folderID)")
            }
            completion(success)
        }
    }

    private static func evaluateDeviceOwner(reason: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            logger.error("Biometric auth not available: \(error?.localizedDescription ?? "unknown")")
            completion(false)
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
            DispatchQueue.main.async {
                if !success {
                    logger.info("Vault auth failed: \(authError?.localizedDescription ?? "cancelled")")
                }
                completion(success)
            }
        }
    }
}
