//
//  main.swift
//
//  clipy
//
//  Command line access to the Clipy app's named clips:
//
//    export GITHUB_TOKEN=$(clipy get github-token)
//

import Foundation

func printHelp() {
    let width = Subcommands.all.map { "\($0.name) \($0.arguments)".count }.max() ?? 0
    var lines = [
        "Usage: clipy <command> [arguments]",
        "",
        "Commands:"
    ]
    for subcommand in Subcommands.all {
        let usage = "\(subcommand.name) \(subcommand.arguments)"
        lines.append("  " + usage.padding(toLength: width + 2, withPad: " ", startingAt: 0) + subcommand.summary)
    }
    lines += [
        "  help" + String(repeating: " ", count: max(2, width - 2)) + "Show this help",
        "",
        "Name a clip in Clipy's search panel with \u{2318}N. Reading clips needs Touch ID",
        "approval in Clipy, which lasts an hour or until `clipy lock`.",
        "",
        "Exit codes: 0 ok, 1 not found or expired, 2 access denied, 3 clip has no text,",
        "            4 Clipy not running, 64 usage error, 70 other failure.",
        "",
        "Environment: \(CLIProtocol.socketPathEnvironmentKey) overrides the socket path",
        "             (default \(SocketClient.defaultPath(environment: [:])))."
    ]
    Output.standard(lines.joined(separator: "\n") + "\n")
}

func run(_ argv: [String]) -> Int32 {
    guard let command = argv.first else {
        printHelp()
        return ExitCode.usage
    }
    switch command {
    case "help", "-h", "--help":
        printHelp()
        return ExitCode.success
    case "--version":
        Output.standard("clipy (protocol \(CLIProtocol.version))\n")
        return ExitCode.success
    default:
        break
    }

    guard let subcommand = Subcommands.named(command) else {
        Output.error("unknown command '\(command)'. Run `clipy help` for the list.")
        return ExitCode.usage
    }

    let client = SocketClient(path: SocketClient.defaultPath())
    do {
        return try subcommand.run(Array(argv.dropFirst()), client: client)
    } catch ClientError.usage(let message) {
        Output.error("\(message)\nUsage: clipy \(subcommand.name) \(subcommand.arguments)")
        return ExitCode.usage
    } catch ClientError.server(let error) {
        Output.error(error.message)
        return ExitCode.forError(error.code)
    } catch ClientError.appNotRunning(let message) {
        Output.error(message)
        return ExitCode.appNotRunning
    } catch ClientError.failure(let message) {
        Output.error(message)
        return ExitCode.failure
    } catch {
        Output.error(error.localizedDescription)
        return ExitCode.failure
    }
}

exit(run(Array(CommandLine.arguments.dropFirst())))
