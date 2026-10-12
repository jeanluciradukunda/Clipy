//
//  CommandLineToolSection.swift
//
//  Clipy
//
//  Preferences section that links the bundled `clipy` command line tool into the PATH.
//

import SwiftUI

// MARK: - Installer
enum CommandLineToolInstaller {

    enum State: Equatable {
        case installed
        case linkedElsewhere(String)
        case notInstalled
        case missingFromBundle
    }

    static let linkPath = "/usr/local/bin/clipy"

    /// The tool inside the app bundle: Clipy.app/Contents/Helpers/clipy.
    static var helperURL: URL {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/clipy")
    }

    /// The command to run by hand when /usr/local/bin is not writable.
    static var manualCommand: String {
        "sudo mkdir -p /usr/local/bin && sudo ln -sf \"\(helperURL.path)\" \(linkPath)"
    }

    static func state() -> State {
        let fileManager = FileManager.default
        guard fileManager.isExecutableFile(atPath: helperURL.path) else { return .missingFromBundle }
        guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: linkPath) else {
            return .notInstalled
        }
        let resolved = URL(fileURLWithPath: destination, relativeTo: URL(fileURLWithPath: "/usr/local/bin"))
            .standardizedFileURL.path
        return resolved == helperURL.standardizedFileURL.path ? .installed : .linkedElsewhere(resolved)
    }

    /// Links the tool into /usr/local/bin, replacing an older link. Fails without admin rights
    /// on most Macs; the caller then shows `manualCommand`.
    static func install() throws {
        let fileManager = FileManager.default
        if (try? fileManager.destinationOfSymbolicLink(atPath: linkPath)) != nil {
            try fileManager.removeItem(atPath: linkPath)
        }
        try fileManager.createSymbolicLink(atPath: linkPath, withDestinationPath: helperURL.path)
    }
}

// MARK: - Section
struct CommandLineToolSection: View {
    @State private var state = CommandLineToolInstaller.state()
    @State private var showManualCommand = false

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("clipy command line tool")
                            .font(.system(size: 12, weight: .medium))
                        Text(statusText)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if state != .installed && state != .missingFromBundle {
                        Button("Install\u{2026}", action: install)
                    }
                }

                Text("Name a clip in the search panel, then read it in a terminal with clipy get <name>. Reading needs Touch ID approval, which lasts an hour.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if showManualCommand {
                    Text("Clipy cannot write to /usr/local/bin. Run this in Terminal instead:")
                        .font(.system(size: 10))
                    HStack {
                        Text(CommandLineToolInstaller.manualCommand)
                            .font(.system(size: 10, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(2)
                        Spacer()
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(CommandLineToolInstaller.manualCommand, forType: .string)
                        }
                        .controlSize(.small)
                    }
                }
            }
        } header: {
            Label("Command Line", systemImage: "terminal")
        }
        .onAppear { state = CommandLineToolInstaller.state() }
    }

    private var statusText: String {
        switch state {
        case .installed: return "Installed at \(CommandLineToolInstaller.linkPath)"
        case .linkedElsewhere(let path): return "\(CommandLineToolInstaller.linkPath) points to \(path)"
        case .notInstalled: return "Not installed"
        case .missingFromBundle: return "Not included in this build of Clipy"
        }
    }

    private func install() {
        do {
            try CommandLineToolInstaller.install()
            showManualCommand = false
        } catch {
            showManualCommand = true
        }
        state = CommandLineToolInstaller.state()
    }
}
