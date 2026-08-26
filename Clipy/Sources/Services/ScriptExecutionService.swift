//
//  ScriptExecutionService.swift
//
//  Clipy
//
//  Executes shell scripts for script snippets with timeout and output capture.
//

import Foundation
import Cocoa
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy", category: "ScriptExecution")

struct ScriptExecutionService {

    struct Result {
        let output: String
        let exitCode: Int32
        let timedOut: Bool
        let error: String?
    }

    /// Maximum output size in bytes (1 MB)
    private static let maxOutputSize = 1_048_576

    /// Execute a shell script and return the result via completion handler.
    /// Reads the clipboard on the calling thread, then runs the script on a background thread.
    /// Completion is called on the main queue.
    static func execute(
        script: String,
        shell: String = CPYSnippet.defaultShell,
        timeout: TimeInterval = TimeInterval(CPYSnippet.defaultTimeout),
        environment: [String: String] = [:],
        completion: @escaping (Result) -> Void
    ) {
        // Read clipboard eagerly on the calling thread to avoid DispatchQueue.main.sync deadlocks
        let clipboard = NSPasteboard.general.string(forType: .string)

        DispatchQueue.global(qos: .userInitiated).async {
            let result = run(script: script, shell: shell, timeout: timeout, clipboard: clipboard, environment: environment)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    /// Synchronous script execution (called from background thread).
    private static func run(
        script: String,
        shell: String,
        timeout: TimeInterval,
        clipboard: String?,
        environment: [String: String]
    ) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-c", script]
        process.currentDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())

        var env = ProcessInfo.processInfo.environment
        if let clipboard {
            env["CLIPBOARD"] = clipboard
        }
        for (key, value) in environment {
            env[key] = value
        }
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            logger.error("Failed to launch script: \(error.localizedDescription)")
            return Result(output: "", exitCode: -1, timedOut: false, error: error.localizedDescription)
        }

        // Thread-safe timeout flag
        let lock = NSLock()
        var timedOut = false

        let timer = DispatchSource.makeTimerSource(queue: .global())
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler {
            if process.isRunning {
                lock.lock()
                timedOut = true
                lock.unlock()
                process.terminate()
                logger.warning("Script timed out after \(timeout)s, sending SIGTERM")
                // Escalate to SIGKILL if process doesn't exit within 2s
                let pid = process.processIdentifier
                DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                    if process.isRunning {
                        kill(pid, SIGKILL)
                        logger.warning("Script did not exit after SIGTERM, sent SIGKILL to pid \(pid)")
                    }
                }
            }
        }
        timer.resume()

        // Read pipe data concurrently BEFORE waitUntilExit to prevent kernel pipe buffer deadlock.
        // Drain fully even past maxOutputSize so the child process can't block on a full pipe buffer.
        var stdoutData = Data()
        var stderrData = Data()
        let readGroup = DispatchGroup()

        readGroup.enter()
        DispatchQueue.global().async {
            stdoutData = drainPipe(stdoutPipe.fileHandleForReading, limit: maxOutputSize)
            readGroup.leave()
        }

        readGroup.enter()
        DispatchQueue.global().async {
            stderrData = drainPipe(stderrPipe.fileHandleForReading, limit: maxOutputSize)
            readGroup.leave()
        }

        process.waitUntilExit()
        readGroup.wait()
        timer.cancel()

        lock.lock()
        let didTimeout = timedOut
        lock.unlock()

        let output = String(data: stdoutData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorOutput = String(data: stderrData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus != 0 && !didTimeout {
            logger.info("Script exited with code \(process.terminationStatus): \(errorOutput)")
        }

        return Result(
            output: output,
            exitCode: process.terminationStatus,
            timedOut: didTimeout,
            error: errorOutput.isEmpty ? nil : errorOutput
        )
    }

    /// Drain a pipe fully to EOF, keeping only the first `limit` bytes.
    /// Continues reading past the limit so the child process doesn't block on a full pipe buffer.
    private static func drainPipe(_ handle: FileHandle, limit: Int) -> Data {
        var collected = Data()
        let chunkSize = 64 * 1024
        var stored = 0
        while true {
            let chunk = handle.readData(ofLength: chunkSize)
            if chunk.isEmpty { break }
            if stored < limit {
                let remaining = limit - stored
                collected.append(chunk.prefix(remaining))
                stored += min(chunk.count, remaining)
            }
        }
        return collected
    }

    /// Environment variables available to script snippets (for UI hints).
    static let availableEnvVars: [(name: String, desc: String)] = [
        ("$CLIPBOARD", "Current clipboard text content"),
        ("$HOME", "User home directory"),
        ("$PATH", "System PATH (inherited)")
    ]
}
