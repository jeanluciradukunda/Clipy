//
//  AccessHandlers.swift
//
//  Clipy
//
//  `clipy status`, `clipy unlock` and `clipy lock`: the state of command line access.
//  None of these read clips, so none needs the gate open first.
//

import Foundation

@MainActor
struct StatusHandler: CLICommandHandler {
    let name = CLIStatusCommand.name
    let requiresUnlock = false
    let gate: CLIAccessGate

    func handle(_ request: CLIRequest) async throws -> CLIJSON? {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let result = CLIStatusCommand.Result(appVersion: version,
                                             locked: !gate.isUnlocked,
                                             unlockedUntil: gate.isUnlocked ? gate.unlockedUntil : nil)
        return try CLIJSON(encoding: result)
    }
}

@MainActor
struct UnlockHandler: CLICommandHandler {
    let name = CLIUnlockCommand.name
    let requiresUnlock = false
    let gate: CLIAccessGate

    func handle(_ request: CLIRequest) async throws -> CLIJSON? {
        guard await gate.unlock() else {
            throw CLIError(code: .denied, message: "Access was not approved in Clipy")
        }
        return try CLIJSON(encoding: CLIUnlockCommand.Result(unlockedUntil: gate.unlockedUntil))
    }
}

@MainActor
struct LockHandler: CLICommandHandler {
    let name = CLILockCommand.name
    let requiresUnlock = false
    let gate: CLIAccessGate

    func handle(_ request: CLIRequest) async throws -> CLIJSON? {
        gate.lock()
        return nil
    }
}
