//
//  CLIProtocol.swift
//
//  Clipy
//
//  The wire protocol between the Clipy app and the `clipy` command line tool.
//  Compiled into both targets, so it uses Foundation only.
//
//  One request per connection over a Unix domain socket, one newline-terminated
//  JSON object each way:
//
//    request  {"v":1,"cmd":"get","args":{"name":"github-token"}}
//    reply    {"ok":true,"data":{...}}
//             {"ok":false,"error":{"code":"not_found","message":"..."}}
//
//  The envelope never changes when a command is added: `cmd` is an open string and
//  `args` / `data` are free-form JSON that each command decodes into its own types
//  (see CLICommands.swift). Bump `CLIProtocol.version` only for envelope changes.
//

import Foundation

// MARK: - Constants
enum CLIProtocol {
    static let version = 1
    static let socketFileName = "clipy.sock"
    /// Environment variable that overrides the socket path the CLI connects to.
    static let socketPathEnvironmentKey = "CLIPY_SOCKET"
    /// Requests larger than this are rejected; every command so far is tiny.
    static let maxRequestBytes = 64 * 1024

    /// The socket inside the app's Application Support folder, e.g.
    /// `~/Library/Application Support/Clipy/clipy.sock`.
    static func socketPath(supportDirectoryName: String) -> String {
        let base = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first
            ?? (NSHomeDirectory() as NSString).appendingPathComponent("Library/Application Support")
        return ((base as NSString).appendingPathComponent(supportDirectoryName) as NSString)
            .appendingPathComponent(socketFileName)
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// MARK: - JSON Value
/// Free-form JSON, so the envelope can carry any command's arguments and results.
enum CLIJSON: Codable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([CLIJSON])
    case object([String: CLIJSON])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([CLIJSON].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: CLIJSON].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    /// Wraps any Encodable value, e.g. a command's typed result.
    init<T: Encodable>(encoding value: T) throws {
        let data = try CLIProtocol.makeEncoder().encode(value)
        self = try CLIProtocol.makeDecoder().decode(CLIJSON.self, from: data)
    }

    /// Unwraps into a command's typed arguments or result.
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try CLIProtocol.makeEncoder().encode(self)
        return try CLIProtocol.makeDecoder().decode(type, from: data)
    }
}

// MARK: - Envelope
struct CLIRequest: Codable, Equatable {
    var version: Int
    var cmd: String
    var args: CLIJSON?

    private enum CodingKeys: String, CodingKey {
        case version = "v"
        case cmd
        case args
    }

    init(cmd: String, args: CLIJSON? = nil, version: Int = CLIProtocol.version) {
        self.version = version
        self.cmd = cmd
        self.args = args
    }

    init<Args: Encodable>(cmd: String, arguments: Args) throws {
        self.init(cmd: cmd, args: try CLIJSON(encoding: arguments))
    }

    /// Decodes `args` into a command's argument type, or fails with `bad_request`.
    func arguments<Args: Decodable>(_ type: Args.Type) throws -> Args {
        do {
            return try (args ?? .object([:])).decode(type)
        } catch {
            throw CLIError(code: .badRequest, message: "Invalid arguments for '\(cmd)'")
        }
    }
}

struct CLIReply: Codable, Equatable {
    var ok: Bool
    var data: CLIJSON?
    var error: CLIError?

    static func success(_ data: CLIJSON? = nil) -> CLIReply {
        CLIReply(ok: true, data: data, error: nil)
    }

    static func failure(_ error: CLIError) -> CLIReply {
        CLIReply(ok: false, data: nil, error: error)
    }

    /// Decodes `data` into a command's result type.
    func result<Result: Decodable>(_ type: Result.Type) throws -> Result {
        try (data ?? .object([:])).decode(type)
    }
}

// MARK: - Errors
struct CLIError: Codable, Equatable, Error {
    /// An open set of codes, so a new command can add its own without a protocol change.
    struct Code: RawRepresentable, Codable, Hashable {
        let rawValue: String
        init(rawValue: String) { self.rawValue = rawValue }

        static let badRequest = Code(rawValue: "bad_request")
        static let unsupportedVersion = Code(rawValue: "unsupported_version")
        static let unknownCommand = Code(rawValue: "unknown_command")
        static let locked = Code(rawValue: "locked")
        static let denied = Code(rawValue: "denied")
        static let notFound = Code(rawValue: "not_found")
        static let expired = Code(rawValue: "expired")
        static let notText = Code(rawValue: "not_text")
        static let internalError = Code(rawValue: "internal")
    }

    var code: Code
    var message: String
}
