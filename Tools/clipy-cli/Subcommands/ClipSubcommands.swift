//
//  ClipSubcommands.swift
//
//  clipy
//
//  Subcommands that read named clips.
//

import Foundation

/// `clipy get <name>`: prints the clip's text exactly, with nothing added,
/// so `$(clipy get name)` substitutes the clip as it was copied.
struct GetSubcommand: Subcommand {
    let name = CLIGetCommand.name
    let arguments = "<name>"
    let summary = "Print the text of the clip with this name"

    func run(_ arguments: [String], client: SocketClient) throws -> Int32 {
        guard arguments.count == 1, let clipName = arguments.first, !clipName.isEmpty else {
            throw ClientError.usage("get takes exactly one clip name")
        }
        let result = try client.call(name, arguments: CLIGetCommand.Arguments(name: clipName),
                                     expecting: CLIGetCommand.Result.self)
        Output.standard(result.content)
        return ExitCode.success
    }
}

/// `clipy list`: one named clip per line, with its expiry after a tab.
struct ListSubcommand: Subcommand {
    let name = CLIListCommand.name
    let arguments = ""
    let summary = "List named clips and when they expire"

    func run(_ arguments: [String], client: SocketClient) throws -> Int32 {
        guard arguments.isEmpty else { throw ClientError.usage("list takes no arguments") }
        let result = try client.call(name, arguments: CLIListCommand.Arguments(),
                                     expecting: CLIListCommand.Result.self)
        for clip in result.clips {
            if let expiresAt = clip.expiresAt {
                Output.standard("\(clip.name)\texpires \(Output.date(expiresAt))\n")
            } else {
                Output.standard("\(clip.name)\n")
            }
        }
        return ExitCode.success
    }
}
