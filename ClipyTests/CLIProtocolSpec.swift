import Quick
import Nimble
@testable import Clipy

class CLIProtocolSpec: QuickSpec {
    override class func spec() {

        func json(_ value: some Encodable) -> String {
            String(decoding: try! CLIProtocol.makeEncoder().encode(value), as: UTF8.self)
        }

        describe("CLIRequest") {
            it("puts the protocol version under the key v") {
                let request = try! CLIRequest(cmd: "get", arguments: CLIGetCommand.Arguments(name: "token"))

                expect(json(request)) == #"{"args":{"name":"token"},"cmd":"get","v":1}"#
            }

            it("decodes a command's typed arguments") {
                let data = Data(#"{"v":1,"cmd":"get","args":{"name":"token"}}"#.utf8)
                let request = try! CLIProtocol.makeDecoder().decode(CLIRequest.self, from: data)

                expect(try! request.arguments(CLIGetCommand.Arguments.self).name) == "token"
            }

            it("reports arguments of the wrong shape as a bad request") {
                let request = CLIRequest(cmd: "get", args: .object(["nam": .string("x")]))

                expect { try request.arguments(CLIGetCommand.Arguments.self) }
                    .to(throwError(CLIError(code: .badRequest, message: "Invalid arguments for 'get'")))
            }

            it("decodes a command with no arguments") {
                let data = Data(#"{"v":1,"cmd":"list"}"#.utf8)
                let request = try! CLIProtocol.makeDecoder().decode(CLIRequest.self, from: data)

                expect(try! request.arguments(CLIListCommand.Arguments.self)) == CLIEmpty()
            }
        }

        describe("CLIReply") {
            it("carries a typed result, dates included") {
                let expiry = Date(timeIntervalSince1970: 1_900_000_000)
                let result = CLIGetCommand.Result(name: "token", content: "secret\n", expiresAt: expiry)
                let reply = CLIReply.success(try! CLIJSON(encoding: result))

                let decoded = try! CLIProtocol.makeDecoder().decode(CLIReply.self, from: CLIProtocol.makeEncoder().encode(reply))

                expect(try! decoded.result(CLIGetCommand.Result.self)) == result
            }

            it("keeps error codes it does not know, so new commands can add their own") {
                let data = Data(#"{"ok":false,"error":{"code":"quota_exceeded","message":"Too many"}}"#.utf8)
                let reply = try! CLIProtocol.makeDecoder().decode(CLIReply.self, from: data)

                expect(reply.ok) == false
                expect(reply.error?.code.rawValue) == "quota_exceeded"
            }
        }

        describe("CLIProtocol.socketPath") {
            it("lives in the app's Application Support folder") {
                expect(CLIProtocol.socketPath(supportDirectoryName: "ClipyDev"))
                    .to(endWith("/Library/Application Support/ClipyDev/clipy.sock"))
            }
        }
    }
}
