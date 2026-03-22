//
//  PluginManager.swift
//
//  Clipy
//
//  Scans ~/.clipy/plugins/, loads plugin manifests, and runs plugins
//  via ScriptExecutionService.
//

import Foundation
import Cocoa
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy", category: "Plugins")

private let kPluginEnabledStates = "kCPYPluginEnabledStates"

@MainActor
class PluginManager: ObservableObject {
    static let shared = PluginManager()

    @Published var plugins = [Plugin]()

    /// Fast check to skip auto-plugin work when none are registered.
    var hasAutoPlugins: Bool {
        plugins.contains { $0.isEnabled && $0.trigger == .auto }
    }

    /// Base directory for user plugins.
    static var pluginsDirectoryURL: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".clipy/plugins", isDirectory: true)
    }

    private var fileWatcher: DispatchSourceFileSystemObject?
    private var reloadDebounce: DispatchWorkItem?

    private init() {
        ensurePluginsDirectory()
        reload()
        startWatching()
    }

    // MARK: - Directory Setup

    private func ensurePluginsDirectory() {
        let url = Self.pluginsDirectoryURL
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    // MARK: - Loading

    func reload() {
        let baseURL = Self.pluginsDirectoryURL
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            plugins = []
            return
        }

        let enabledIDs = enabledPluginIDs()

        plugins = contents.compactMap { dirURL -> Plugin? in
            guard (try? dirURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { return nil }
            let manifestURL = dirURL.appendingPathComponent("manifest.json")
            guard let data = try? Data(contentsOf: manifestURL) else {
                logger.warning("No manifest.json in plugin \(dirURL.lastPathComponent)")
                return nil
            }
            guard var plugin = try? JSONDecoder().decode(Plugin.self, from: data) else {
                logger.error("Invalid manifest.json in plugin \(dirURL.lastPathComponent)")
                return nil
            }
            plugin = Plugin(
                id: dirURL.lastPathComponent,
                name: plugin.name,
                version: plugin.version,
                description: plugin.description,
                author: plugin.author,
                type: plugin.type,
                trigger: plugin.trigger,
                inputTypes: plugin.inputTypes,
                command: plugin.command,
                timeout: plugin.timeout,
                directoryURL: dirURL
            )
            plugin.isEnabled = enabledIDs[plugin.id] ?? true
            return plugin
        }

        logger.info("Loaded \(self.plugins.count) plugin(s)")
    }

    // MARK: - Plugin Execution

    /// Run a plugin with the given input string.
    func run(_ plugin: Plugin, input: String, completion: @escaping (ScriptExecutionService.Result) -> Void) {
        guard let dirURL = plugin.directoryURL else {
            completion(ScriptExecutionService.Result(output: "", exitCode: -1, timedOut: false, error: "Plugin directory not found"))
            return
        }

        // Quote the command path to handle spaces/special characters safely
        let commandPath = dirURL.appendingPathComponent(plugin.command).path
        let quotedCommand = "'\(commandPath.replacingOccurrences(of: "'", with: "'\\''"))'"

        ScriptExecutionService.execute(
            script: quotedCommand,
            shell: CPYSnippet.defaultShell,
            timeout: TimeInterval(plugin.timeout),
            environment: ["CLIPY_INPUT": input, "PLUGIN_DIR": dirURL.path],
            completion: completion
        )
    }

    /// Run all enabled auto-trigger plugins on the given input.
    func runAutoPlugins(input: String) {
        guard hasAutoPlugins else { return }
        let autoPlugins = plugins.filter { $0.isEnabled && $0.trigger == .auto }
        for plugin in autoPlugins {
            run(plugin, input: input) { result in
                if result.exitCode != 0 {
                    logger.warning("Auto plugin '\(plugin.name)' failed: \(result.error ?? "unknown")")
                }
            }
        }
    }

    // MARK: - Enable/Disable

    func setEnabled(_ pluginID: String, enabled: Bool) {
        if let index = plugins.firstIndex(where: { $0.id == pluginID }) {
            plugins[index].isEnabled = enabled
        }
        saveEnabledPluginIDs()
    }

    private func enabledPluginIDs() -> [String: Bool] {
        UserDefaults.standard.dictionary(forKey: kPluginEnabledStates) as? [String: Bool] ?? [:]
    }

    private func saveEnabledPluginIDs() {
        var states = [String: Bool]()
        for plugin in plugins {
            states[plugin.id] = plugin.isEnabled
        }
        UserDefaults.standard.set(states, forKey: kPluginEnabledStates)
    }

    // MARK: - File Watching

    private func startWatching() {
        let path = Self.pluginsDirectoryURL.path
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .global()
        )

        source.setEventHandler { [weak self] in
            // Debounce: wait 0.5s after last event before reloading
            DispatchQueue.main.async {
                self?.reloadDebounce?.cancel()
                let work = DispatchWorkItem { [weak self] in
                    self?.reload()
                }
                self?.reloadDebounce = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        fileWatcher = source
    }

    /// Open the plugins directory in Finder.
    func openPluginsFolder() {
        NSWorkspace.shared.open(Self.pluginsDirectoryURL)
    }
}
