//
//  AccessSubcommands.swift
//
//  clipy
//
//  Subcommands for the state of command line access in the Clipy app.
//

import Foundation

struct StatusSubcommand: Subcommand {
    let name = CLIStatusCommand.name
    let arguments = ""
    let summary = "Show whether Clipy is running and whether access is unlocked"

    func run(_ arguments: [String], client: SocketClient) throws -> Int32 {
        guard arguments.isEmpty else { throw ClientError.usage("status takes no arguments") }
        let result = try client.call(name, arguments: CLIStatusCommand.Arguments(),
                                     expecting: CLIStatusCommand.Result.self)
        Output.standard("Clipy \(result.appVersion) is running\n")
        if let until = result.unlockedUntil, !result.locked {
            Output.standard("Access is unlocked until \(Output.date(until))\n")
        } else {
            Output.standard("Access is locked; the next get or list asks for Touch ID\n")
        }
        return ExitCode.success
    }
}

struct UnlockSubcommand: Subcommand {
    let name = CLIUnlockCommand.name
    let arguments = ""
    let summary = "Ask for Touch ID now, so later gets do not wait for it"

    func run(_ arguments: [String], client: SocketClient) throws -> Int32 {
        guard arguments.isEmpty else { throw ClientError.usage("unlock takes no arguments") }
        let result = try client.call(name, arguments: CLIUnlockCommand.Arguments(),
                                     expecting: CLIUnlockCommand.Result.self)
        if let until = result.unlockedUntil {
            Output.standard("Unlocked until \(Output.date(until))\n")
        }
        return ExitCode.success
    }
}

struct LockSubcommand: Subcommand {
    let name = CLILockCommand.name
    let arguments = ""
    let summary = "Lock access again until the next Touch ID approval"

    func run(_ arguments: [String], client: SocketClient) throws -> Int32 {
        guard arguments.isEmpty else { throw ClientError.usage("lock takes no arguments") }
        _ = try client.call(name, arguments: CLILockCommand.Arguments(), expecting: CLILockCommand.Result.self)
        return ExitCode.success
    }
}
