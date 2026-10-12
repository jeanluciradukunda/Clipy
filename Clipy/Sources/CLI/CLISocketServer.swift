//
//  CLISocketServer.swift
//
//  Clipy
//
//  A Unix domain socket that the `clipy` command line tool connects to.
//  Reads one newline-terminated request per connection, hands it to `handler`,
//  writes the reply and closes. Only processes running as the same user are served.
//

import Foundation
import Darwin
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy", category: "CLISocket")

final class CLISocketServer {

    enum ServerError: Error, CustomStringConvertible {
        case pathTooLong(String)
        case alreadyServing(String)
        case system(String, Int32)

        var description: String {
            switch self {
            case .pathTooLong(let path): return "Socket path is too long: \(path)"
            case .alreadyServing(let path): return "Another process is already serving \(path)"
            case .system(let call, let code): return "\(call) failed: \(String(cString: strerror(code)))"
            }
        }
    }

    typealias Handler = (Data) async -> Data

    let path: String
    private let handler: Handler
    private let queue = DispatchQueue(label: "com.clipy-app.Clipy.cli-socket")
    private var listenFD: Int32 = -1
    private var source: DispatchSourceRead?

    /// Seconds a client may take to send its request.
    private static let readTimeout = 5

    init(path: String, handler: @escaping Handler) {
        self.path = path
        self.handler = handler
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle
    func start() throws {
        stop()
        try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                                withIntermediateDirectories: true)
        try removeStaleSocket()

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ServerError.system("socket", errno) }

        do {
            var address = try Self.address(for: path)
            let bound = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            guard bound == 0 else { throw ServerError.system("bind", errno) }
            // Owner read/write only, on top of the same-user check per connection
            guard chmod(path, 0o600) == 0 else { throw ServerError.system("chmod", errno) }
            guard listen(fd, 16) == 0 else { throw ServerError.system("listen", errno) }
            _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
        } catch {
            close(fd)
            unlink(path)
            throw error
        }

        listenFD = fd
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptPending() }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
        logger.info("Listening for the clipy command line tool at \(self.path, privacy: .public)")
    }

    func stop() {
        guard let source else { return }
        source.cancel()
        self.source = nil
        listenFD = -1
        unlink(path)
    }

    // MARK: - Connections
    private func acceptPending() {
        while true {
            let client = accept(listenFD, nil, nil)
            guard client >= 0 else { return }  // EAGAIN: nothing more to accept
            serve(client)
        }
    }

    private func serve(_ client: Int32) {
        // Accepted sockets inherit O_NONBLOCK from the listener; requests are read blocking
        _ = fcntl(client, F_SETFL, fcntl(client, F_GETFL) & ~O_NONBLOCK)
        var noSigPipe: Int32 = 1
        setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
        var timeout = timeval(tv_sec: Self.readTimeout, tv_usec: 0)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(client, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var peerUID: uid_t = 0
        var peerGID: gid_t = 0
        guard getpeereid(client, &peerUID, &peerGID) == 0, peerUID == getuid() else {
            logger.error("Refused a command line connection from another user")
            close(client)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [handler] in
            guard let request = Self.readRequest(from: client) else {
                close(client)
                return
            }
            Task {
                var reply = await handler(request)
                reply.append(0x0A)
                Self.writeAll(reply, to: client)
                close(client)
            }
        }
    }

    /// Reads up to the first newline (or EOF), capped at `CLIProtocol.maxRequestBytes`.
    private static func readRequest(from fd: Int32) -> Data? {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while data.count <= CLIProtocol.maxRequestBytes {
            let count = read(fd, &buffer, buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
            if let newline = data.firstIndex(of: 0x0A) {
                return data.prefix(upTo: newline)
            }
        }
        guard !data.isEmpty, data.count <= CLIProtocol.maxRequestBytes else { return nil }
        return data
    }

    private static func writeAll(_ data: Data, to fd: Int32) {
        data.withUnsafeBytes { raw in
            guard var pointer = raw.baseAddress else { return }
            var remaining = raw.count
            while remaining > 0 {
                let written = write(fd, pointer, remaining)
                if written <= 0 { return }
                pointer += written
                remaining -= written
            }
        }
    }

    // MARK: - Helpers
    /// Removes a socket file left by a previous run, but refuses if something still answers on it.
    private func removeStaleSocket() throws {
        guard FileManager.default.fileExists(atPath: path) else { return }
        let probe = socket(AF_UNIX, SOCK_STREAM, 0)
        defer { close(probe) }
        if probe >= 0, var address = try? Self.address(for: path) {
            let connected = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(probe, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            if connected == 0 { throw ServerError.alreadyServing(path) }
        }
        unlink(path)
    }

    static func address(for path: String) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard bytes.count < capacity else { throw ServerError.pathTooLong(path) }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: bytes)
            buffer[bytes.count] = 0
        }
        return address
    }
}
