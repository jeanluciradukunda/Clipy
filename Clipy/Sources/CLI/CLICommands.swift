//
//  CLICommands.swift
//
//  Clipy
//
//  The commands the `clipy` tool can send, with their typed arguments and results.
//  Compiled into both the app and the CLI, so both sides agree on each payload.
//
//  To add a command:
//    1. Add an enum here with its `name`, `Arguments` and `Result`.
//    2. Add a handler in Clipy/Sources/CLI/Handlers and register it in
//       `CLIAccessService.defaultHandlers`.
//    3. Add a subcommand in Tools/clipy-cli/Subcommands and register it in
//       `Subcommands.all`.
//

import Foundation

/// Arguments or result for a command that has none.
struct CLIEmpty: Codable, Equatable {}

/// A clip as the CLI sees it, without its content.
struct CLINamedClip: Codable, Equatable {
    var name: String
    var expiresAt: Date?
}

enum CLIGetCommand {
    static let name = "get"
    struct Arguments: Codable, Equatable {
        var name: String
    }
    struct Result: Codable, Equatable {
        var name: String
        var content: String
        var expiresAt: Date?
    }
}

enum CLIListCommand {
    static let name = "list"
    typealias Arguments = CLIEmpty
    struct Result: Codable, Equatable {
        var clips: [CLINamedClip]
    }
}

enum CLIStatusCommand {
    static let name = "status"
    typealias Arguments = CLIEmpty
    struct Result: Codable, Equatable {
        var appVersion: String
        var locked: Bool
        var unlockedUntil: Date?
    }
}

enum CLIUnlockCommand {
    static let name = "unlock"
    typealias Arguments = CLIEmpty
    struct Result: Codable, Equatable {
        var unlockedUntil: Date?
    }
}

enum CLILockCommand {
    static let name = "lock"
    typealias Arguments = CLIEmpty
    typealias Result = CLIEmpty
}
