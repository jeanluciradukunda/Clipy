//
//  VaultAuthService.swift
//
//  Clipy
//
//  Provides Touch ID / password authentication for vault snippet folders.
//

import AppKit
import LocalAuthentication
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy", category: "VaultAuth")

@MainActor
final class VaultAuthService {
    static let shared = VaultAuthService()

    /// Posted after any folder is locked, so open views can close what they show.
    static let didLock = Notification.Name("com.clipy-app.Clipy.vaultDidLock")

    /// Folder IDs that have been unlocked this session
    private var unlockedFolderIDs = Set<String>()
    /// Bumped on every lock: an authentication that started before a lock must not unlock after it.
    private(set) var lockGeneration = 0

    /// Asks the device owner to authenticate; tests replace it to avoid a real Touch ID prompt.
    var evaluate: (_ reason: String, _ completion: @escaping (Bool) -> Void) -> Void = VaultAuthService.evaluateDeviceOwner

    private init() {
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.lockAll() }
            }
        }
        DistributedNotificationCenter.default().addObserver(forName: .init("com.apple.screenIsLocked"), object: nil,
                                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.lockAll() }
        }
    }

    func isUnlocked(_ folderID: String) -> Bool {
        unlockedFolderIDs.contains(folderID)
    }

    /// Whether a snippet may be shown or pasted now: always outside a vault, only while its vault is unlocked.
    func allows(_ snippet: CPYSnippet) -> Bool {
        guard let folder = snippet.folder, folder.isVault else { return true }
        return isUnlocked(folder.identifier)
    }

    /// Whether a vault that was open at `generation` is still open now, with no lock in between.
    func isStillUnlocked(_ folderID: String, since generation: Int) -> Bool {
        return lockGeneration == generation && isUnlocked(folderID)
    }

    func lockAll() {
        unlockedFolderIDs.removeAll()
        didChangeLocks()
    }

    func lock(_ folderID: String) {
        unlockedFolderIDs.remove(folderID)
        didChangeLocks()
    }

    private func didChangeLocks() {
        lockGeneration += 1
        NotificationCenter.default.post(name: Self.didLock, object: self)
    }

    /// Authenticate to unlock a vault folder. Calls completion on main thread. `force` asks again even when the
    /// folder is already unlocked this session, for actions that remove protection.
    func authenticate(folderID: String, reason: String = "Unlock vault folder", force: Bool = false, completion: @escaping (Bool) -> Void) {
        if !force && unlockedFolderIDs.contains(folderID) {
            completion(true)
            return
        }
        let generation = lockGeneration
        evaluate(reason) { [weak self] success in
            let granted = success && self?.lockGeneration == generation
            if granted && !force {
                UsageMetricsService.shared.track(.vaultUnlocked)
                self?.unlockedFolderIDs.insert(folderID)
                logger.info("Vault folder unlocked: \(folderID)")
            }
            completion(granted)
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

/// A block-based NotificationCenter observation that is removed when this object is released.
/// The handler runs synchronously on the posting thread, which for `VaultAuthService.didLock` is the main thread.
final class NotificationObserver {
    var handler: (@MainActor () -> Void)?
    private var token: NSObjectProtocol?

    init(name: Notification.Name) {
        token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated { self?.handler?() }
        }
    }

    deinit {
        if let token { NotificationCenter.default.removeObserver(token) }
    }
}
