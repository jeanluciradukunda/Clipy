//
//  CLIAccessService.swift
//
//  Clipy
//
//  Serves the `clipy` command line tool. Requests arrive over a Unix domain socket
//  and are routed by command name to a registered `CLICommandHandler`. Handlers that
//  read clips require the access gate (Touch ID) to be open.
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy", category: "CLIAccess")

// MARK: - Handler
@MainActor
protocol CLICommandHandler {
    /// The `cmd` value this handler answers, e.g. "get".
    var name: String { get }
    /// When true, the gate must be open; a locked gate prompts for Touch ID first.
    var requiresUnlock: Bool { get }
    /// Returns the reply's `data`, or throws a `CLIError`.
    func handle(_ request: CLIRequest) async throws -> CLIJSON?
}

// MARK: - Service
@MainActor
final class CLIAccessService {

    static let shared = CLIAccessService()

    let gate: CLIAccessGate
    let socketPath: String
    private(set) var handlers = [String: CLICommandHandler]()
    private var server: CLISocketServer?

    /// `gate` defaults to Touch ID; it is built here because default arguments run off the main actor.
    init(gate: CLIAccessGate? = nil,
         socketPath: String = CLIProtocol.socketPath(supportDirectoryName: Constants.Application.supportDirectoryName),
         handlers: [CLICommandHandler]? = nil) {
        let gate = gate ?? TouchIDAccessGate()
        self.gate = gate
        self.socketPath = socketPath
        (handlers ?? Self.defaultHandlers(gate: gate)).forEach(register)
    }

    static func defaultHandlers(gate: CLIAccessGate) -> [CLICommandHandler] {
        return [
            GetClipHandler(),
            ListClipsHandler(),
            StatusHandler(gate: gate),
            UnlockHandler(gate: gate),
            LockHandler(gate: gate)
        ]
    }

    /// Adds a command, replacing any handler already registered under its name.
    func register(_ handler: CLICommandHandler) {
        handlers[handler.name] = handler
    }

    // MARK: Lifecycle
    func start() {
        let server = CLISocketServer(path: socketPath) { [weak self] data in
            guard let self else { return Data() }
            return await self.respond(to: data)
        }
        do {
            try server.start()
            self.server = server
        } catch {
            logger.error("Command line access unavailable: \(String(describing: error), privacy: .public)")
        }
    }

    func stop() {
        server?.stop()
        server = nil
        gate.lock()
    }

    // MARK: Routing
    func respond(to data: Data) async -> Data {
        let reply: CLIReply
        if let request = try? CLIProtocol.makeDecoder().decode(CLIRequest.self, from: data) {
            reply = await respond(to: request)
        } else {
            reply = .failure(CLIError(code: .badRequest, message: "Request is not valid JSON"))
        }
        return (try? CLIProtocol.makeEncoder().encode(reply)) ?? Data()
    }

    func respond(to request: CLIRequest) async -> CLIReply {
        guard request.version == CLIProtocol.version else {
            return .failure(CLIError(code: .unsupportedVersion,
                                     message: "This Clipy speaks protocol \(CLIProtocol.version), the tool sent \(request.version). Update one to match the other."))
        }
        guard let handler = handlers[request.cmd] else {
            return .failure(CLIError(code: .unknownCommand, message: "Unknown command '\(request.cmd)'"))
        }
        if handler.requiresUnlock, !gate.isUnlocked {
            guard await gate.unlock() else {
                return .failure(CLIError(code: .denied, message: "Access was not approved in Clipy"))
            }
        }
        do {
            return .success(try await handler.handle(request))
        } catch let error as CLIError {
            return .failure(error)
        } catch {
            logger.error("Command '\(request.cmd, privacy: .public)' failed: \(error.localizedDescription)")
            return .failure(CLIError(code: .internalError, message: "Clipy could not complete '\(request.cmd)'"))
        }
    }
}
