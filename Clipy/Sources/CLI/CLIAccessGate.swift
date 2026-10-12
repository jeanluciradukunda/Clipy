//
//  CLIAccessGate.swift
//
//  Clipy
//
//  Decides whether the `clipy` command line tool may read clips right now.
//  Access opens with Touch ID (or the login password) and closes after a while,
//  on `clipy lock`, or when the app quits.
//

import Foundation
import LocalAuthentication
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy", category: "CLIAccess")

@MainActor
protocol CLIAccessGate: AnyObject {
    var isUnlocked: Bool { get }
    var unlockedUntil: Date? { get }
    /// Asks the user to authenticate unless already unlocked. Returns whether access is open.
    func unlock() async -> Bool
    func lock()
}

@MainActor
final class TouchIDAccessGate: CLIAccessGate {

    nonisolated static let defaultUnlockDuration: TimeInterval = 60 * 60

    private let unlockDuration: TimeInterval
    private(set) var unlockedUntil: Date?
    /// Shared by concurrent requests, so several `clipy get` calls show one prompt.
    private var pendingUnlock: Task<Bool, Never>?

    init(unlockDuration: TimeInterval = TouchIDAccessGate.defaultUnlockDuration) {
        self.unlockDuration = unlockDuration
    }

    var isUnlocked: Bool {
        guard let unlockedUntil else { return false }
        return unlockedUntil > Date()
    }

    func unlock() async -> Bool {
        if isUnlocked { return true }
        if let pendingUnlock { return await pendingUnlock.value }

        let task = Task { @MainActor in await Self.authenticate() }
        pendingUnlock = task
        let success = await task.value
        pendingUnlock = nil

        if success {
            unlockedUntil = Date().addingTimeInterval(unlockDuration)
            logger.info("Command line access unlocked")
        }
        return success
    }

    func lock() {
        unlockedUntil = nil
        logger.info("Command line access locked")
    }

    private static func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Deny"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            logger.error("Authentication not available: \(error?.localizedDescription ?? "unknown")")
            return false
        }
        do {
            // macOS shows this as "Clipy is trying to <reason>."
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "allow the clipy command line tool to read your named clips"
            )
        } catch {
            logger.info("Command line access denied: \(error.localizedDescription)")
            return false
        }
    }
}
