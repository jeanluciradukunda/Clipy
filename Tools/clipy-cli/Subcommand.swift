//
//  Subcommand.swift
//
//  clipy
//
//  The `clipy` tool is a list of subcommands. Each one parses its own arguments,
//  sends one request to the Clipy app, and prints the reply.
//
//  To add a subcommand, write a type conforming to `Subcommand` in Subcommands/
//  and add it to `Subcommands.all`. Its request and reply types live in
//  Clipy/Sources/CLI/CLICommands.swift, shared with the app.
//

import Foundation

protocol Subcommand {
    /// The word typed after `clipy`, e.g. "get".
    var name: String { get }
    /// Arguments shown in help, e.g. "<name>".
    var arguments: String { get }
    /// One line for `clipy help`.
    var summary: String { get }
    /// Runs the subcommand and returns the process exit code.
    func run(_ arguments: [String], client: SocketClient) throws -> Int32
}

enum Subcommands {
    static let all: [Subcommand] = [
        GetSubcommand(),
        ListSubcommand(),
        StatusSubcommand(),
        UnlockSubcommand(),
        LockSubcommand()
    ]

    static func named(_ name: String) -> Subcommand? {
        all.first { $0.name == name }
    }
}

// MARK: - Exit Codes
/// Documented in `clipy help`; scripts may rely on them, so only ever add new ones.
enum ExitCode {
    static let success: Int32 = 0
    static let notFound: Int32 = 1
    static let accessDenied: Int32 = 2
    static let notText: Int32 = 3
    static let appNotRunning: Int32 = 4
    static let usage: Int32 = 64      // EX_USAGE
    static let failure: Int32 = 70    // EX_SOFTWARE

    static func forError(_ code: CLIError.Code) -> Int32 {
        switch code {
        case .notFound, .expired: return notFound
        case .locked, .denied: return accessDenied
        case .notText: return notText
        case .badRequest: return usage
        default: return failure
        }
    }
}

// MARK: - Errors
enum ClientError: Error {
    /// Wrong arguments; the message is printed with the subcommand's usage line.
    case usage(String)
    /// The app replied with an error.
    case server(CLIError)
    /// The app is not running or not listening.
    case appNotRunning(String)
    /// Anything else: a broken reply, a timeout.
    case failure(String)
}

// MARK: - Output
enum Output {
    static func standard(_ text: String) {
        FileHandle.standardOutput.write(Data(text.utf8))
    }

    static func error(_ text: String) {
        FileHandle.standardError.write(Data("clipy: \(text)\n".utf8))
    }

    private static let expiryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func date(_ date: Date) -> String {
        expiryFormatter.string(from: date)
    }
}

// MARK: - Round Trip
extension SocketClient {
    /// Sends one command and decodes its result, turning an error reply into `ClientError.server`.
    func call<Args: Encodable, Result: Decodable>(_ cmd: String, arguments: Args, expecting: Result.Type) throws -> Result {
        let reply = try send(try CLIRequest(cmd: cmd, arguments: arguments))
        if let error = reply.error, !reply.ok {
            throw ClientError.server(error)
        }
        do {
            return try reply.result(Result.self)
        } catch {
            throw ClientError.failure("Clipy sent a reply this version of clipy does not understand")
        }
    }
}
