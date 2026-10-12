//
//  SocketClient.swift
//
//  clipy
//
//  Sends one request to the Clipy app's Unix domain socket and reads its reply.
//

import Foundation
import Darwin

struct SocketClient {

    let path: String
    /// Long enough for the user to answer a Touch ID prompt.
    var timeoutSeconds = 120

    /// `CLIPY_SOCKET` if set, otherwise the app's socket in Application Support.
    /// A Debug build of the tool talks to the Debug app ("Clipy Dev").
    static func defaultPath(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        if let override = environment[CLIProtocol.socketPathEnvironmentKey], !override.isEmpty {
            return (override as NSString).expandingTildeInPath
        }
        #if DEBUG
        return CLIProtocol.socketPath(supportDirectoryName: "ClipyDev")
        #else
        return CLIProtocol.socketPath(supportDirectoryName: "Clipy")
        #endif
    }

    func send(_ request: CLIRequest) throws -> CLIReply {
        var payload = try CLIProtocol.makeEncoder().encode(request)
        payload.append(0x0A)
        let replyData = try roundTrip(payload)
        do {
            return try CLIProtocol.makeDecoder().decode(CLIReply.self, from: replyData)
        } catch {
            throw ClientError.failure("Clipy sent a reply that is not valid JSON")
        }
    }

    private func roundTrip(_ payload: Data) throws -> Data {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ClientError.failure("Could not create a socket") }
        defer { close(fd) }

        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
        var timeout = timeval(tv_sec: timeoutSeconds, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else {
            throw ClientError.failure("Socket path is too long: \(path)")
        }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: bytes)
            buffer[bytes.count] = 0
        }
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else {
            let code = errno
            if code == ENOENT || code == ECONNREFUSED {
                throw ClientError.appNotRunning("Clipy is not running, or command line access is off (no socket at \(path))")
            }
            throw ClientError.failure("Could not connect to Clipy: \(String(cString: strerror(code)))")
        }

        try payload.withUnsafeBytes { raw in
            guard var pointer = raw.baseAddress else { return }
            var remaining = raw.count
            while remaining > 0 {
                let written = write(fd, pointer, remaining)
                guard written > 0 else { throw ClientError.failure("Could not send the request to Clipy") }
                pointer += written
                remaining -= written
            }
        }

        var reply = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = read(fd, &buffer, buffer.count)
            if count == 0 { break }
            if count < 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    throw ClientError.failure("Timed out waiting for Clipy after \(timeoutSeconds)s")
                }
                throw ClientError.failure("Could not read Clipy's reply: \(String(cString: strerror(errno)))")
            }
            reply.append(buffer, count: count)
            if reply.last == 0x0A { break }
        }
        guard !reply.isEmpty else { throw ClientError.failure("Clipy closed the connection without replying") }
        return reply
    }
}
