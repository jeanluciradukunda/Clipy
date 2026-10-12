import Quick
import Nimble
@testable import Clipy

/// Stands in for Touch ID: approves or denies without a prompt, and counts the asks.
@MainActor
private final class FakeGate: CLIAccessGate {
    let approve: Bool
    var prompts = 0
    private(set) var unlockedUntil: Date?

    init(approve: Bool) {
        self.approve = approve
    }

    var isUnlocked: Bool { (unlockedUntil ?? .distantPast) > Date() }

    func unlock() async -> Bool {
        if isUnlocked { return true }
        prompts += 1
        if approve { unlockedUntil = Date().addingTimeInterval(60) }
        return approve
    }

    func lock() {
        unlockedUntil = nil
    }
}

/// A test command, described by plain values so it can be built on the main actor.
private struct Echo {
    enum Failure { case none, notFound, unexpected }

    var name: String
    var requiresUnlock: Bool
    var failure = Failure.none
}

private struct UnexpectedError: Error {}

@MainActor
private struct EchoHandler: CLICommandHandler {
    let echo: Echo

    var name: String { echo.name }
    var requiresUnlock: Bool { echo.requiresUnlock }

    func handle(_ request: CLIRequest) async throws -> CLIJSON? {
        switch echo.failure {
        case .none: return .string("echo:\(request.cmd)")
        case .notFound: throw CLIError(code: .notFound, message: "No clip is named 'x'")
        case .unexpected: throw UnexpectedError()
        }
    }
}

/// What one request did: the reply, how often Touch ID was asked, and whether access is open after.
private struct Outcome {
    var reply: CLIReply
    var prompts: Int
    var unlockedAfter: Bool
}

/// Sends `requests` in order to a service built off the socket. `echoes` nil means the default handlers.
@MainActor
private func send(_ requests: [CLIRequest], approve: Bool = true, unlockedBefore: Bool = false,
                  echoes: [Echo]?) async -> [Outcome] {
    let gate = FakeGate(approve: approve)
    if unlockedBefore { _ = await gate.unlock() }
    let handlers = echoes.map { $0.map { EchoHandler(echo: $0) as CLICommandHandler } }
    let service = CLIAccessService(gate: gate, socketPath: "/dev/null", handlers: handlers)
    var outcomes = [Outcome]()
    for request in requests {
        let reply = await service.respond(to: request)
        outcomes.append(Outcome(reply: reply, prompts: gate.prompts, unlockedAfter: gate.isUnlocked))
    }
    return outcomes
}

@MainActor
private func sendRaw(_ data: Data) async -> CLIReply {
    let service = CLIAccessService(gate: FakeGate(approve: true), socketPath: "/dev/null", handlers: [])
    let reply = await service.respond(to: data)
    return try! CLIProtocol.makeDecoder().decode(CLIReply.self, from: reply)
}

@MainActor
private func handlerNames(adding echo: Echo? = nil) -> [String] {
    let service = CLIAccessService(gate: FakeGate(approve: true), socketPath: "/dev/null")
    if let echo { service.register(EchoHandler(echo: echo)) }
    return service.handlers.keys.sorted()
}

class CLIAccessServiceSpec: AsyncSpec {
    override class func spec() {

        describe("CLIAccessService.respond") {
            it("rejects a command nobody registered, without asking for Touch ID") {
                let outcome = await send([CLIRequest(cmd: "write")], echoes: [])[0]

                expect(outcome.reply.error?.code) == .unknownCommand
                expect(outcome.prompts) == 0
            }

            it("rejects a protocol version it does not speak") {
                let outcome = await send([CLIRequest(cmd: "get", version: 2)],
                                         echoes: [Echo(name: "get", requiresUnlock: false)])[0]

                expect(outcome.reply.error?.code) == .unsupportedVersion
            }

            it("asks for Touch ID once before commands that read clips, then runs them") {
                let outcomes = await send([CLIRequest(cmd: "get"), CLIRequest(cmd: "get")],
                                          echoes: [Echo(name: "get", requiresUnlock: true)])

                expect(outcomes[0].reply.data) == .string("echo:get")
                expect(outcomes[1].reply.ok) == true
                expect(outcomes[1].prompts) == 1
            }

            it("refuses when Touch ID is denied") {
                let outcome = await send([CLIRequest(cmd: "get")], approve: false,
                                         echoes: [Echo(name: "get", requiresUnlock: true)])[0]

                expect(outcome.reply.ok) == false
                expect(outcome.reply.error?.code) == .denied
            }

            it("does not ask for Touch ID for commands that read no clips") {
                let outcome = await send([CLIRequest(cmd: "status")], approve: false,
                                         echoes: [Echo(name: "status", requiresUnlock: false)])[0]

                expect(outcome.reply.data) == .string("echo:status")
                expect(outcome.prompts) == 0
            }

            it("passes a handler's own error through") {
                let outcome = await send([CLIRequest(cmd: "get")],
                                         echoes: [Echo(name: "get", requiresUnlock: false, failure: .notFound)])[0]

                expect(outcome.reply.error) == CLIError(code: .notFound, message: "No clip is named 'x'")
            }

            it("hides unexpected errors behind an internal error") {
                let outcome = await send([CLIRequest(cmd: "get")],
                                         echoes: [Echo(name: "get", requiresUnlock: false, failure: .unexpected)])[0]

                expect(outcome.reply.error?.code) == .internalError
            }

            it("answers bytes that are not JSON with a bad request") {
                let reply = await sendRaw(Data("nonsense".utf8))

                expect(reply.error?.code) == .badRequest
            }
        }

        describe("CLIAccessService handlers") {
            it("registers get, list, status, unlock and lock by default") {
                let names = await handlerNames()

                expect(names) == ["get", "list", "lock", "status", "unlock"]
            }

            it("takes a new command without changing the others") {
                let names = await handlerNames(adding: Echo(name: "history", requiresUnlock: true))

                expect(names) == ["get", "history", "list", "lock", "status", "unlock"]
            }

            it("locks access again on lock") {
                let outcome = await send([CLIRequest(cmd: "lock")], unlockedBefore: true, echoes: nil)[0]

                expect(outcome.reply.ok) == true
                expect(outcome.unlockedAfter) == false
            }
        }
    }
}
