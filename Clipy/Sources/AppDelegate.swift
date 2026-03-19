//
//  AppDelegate.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//
//  Created by Econa77 on 2015/06/21.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa
import Sparkle
import Combine
import RealmSwift
import TipKit
import Magnet
import ServiceManagement
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy", category: "App")

@NSApplicationMain
class AppDelegate: NSObject, NSMenuItemValidation {

    // MARK: - Properties
    private var cancellables = Set<AnyCancellable>()
    private var screenshotTask: Task<Void, Never>?

    // MARK: - Init
    override func awakeFromNib() {
        super.awakeFromNib()
        Realm.migration()
    }

    // MARK: - NSMenuItem Validation
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(AppDelegate.clearAllHistory) {
            guard let realm = Realm.safeInstance() else { return false }
            return !realm.objects(CPYClip.self).isEmpty
        }
        return true
    }

    // MARK: - Class Methods
    static func storeTypesDictinary() -> [String: NSNumber] {
        var storeTypes = [String: NSNumber]()
        CPYClipData.availableTypesString.forEach { storeTypes[$0] = NSNumber(value: true) }
        return storeTypes
    }

    // MARK: - Menu Actions
    @objc func showPreferenceWindow() {
        ModernPreferencesWindowController.shared.showWindow(self)
    }

    @objc func showSnippetEditorWindow() {
        ModernSnippetsWindowController.shared.showWindow(self)
    }

    @objc func showSearchPanel() {
        ClipSearchWindowController.shared.show()
    }

    @objc func pasteAsPlainText() {
        let pasteboard = NSPasteboard.general
        guard let string = pasteboard.string(forType: .string) else { return }
        // Re-set as plain text only, stripping all formatting
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        AppEnvironment.current.pasteService.paste()
    }

    @objc func startCollectMode() {
        ClipboardQueueService.shared.startCollecting()
    }

    @objc func stopCollectMode() {
        ClipboardQueueService.shared.stopCollecting()
    }

    @objc func pasteCollectedItems() {
        ClipboardQueueService.shared.pasteMerged()
    }

    @objc func terminate() {
        terminateApplication()
    }

    @objc func clearAllHistory() {
        let isShowAlert = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showAlertBeforeClearHistory)
        if isShowAlert {
            let alert = NSAlert()
            alert.messageText = L10n.clearHistory
            alert.informativeText = L10n.areYouSureYouWantToClearYourClipboardHistory
            alert.addButton(withTitle: L10n.clearHistory)
            alert.addButton(withTitle: L10n.cancel)
            alert.showsSuppressionButton = true

            NSApp.activate(ignoringOtherApps: true)

            let result = alert.runModal()
            if result != NSApplication.ModalResponse.alertFirstButtonReturn { return }

            if alert.suppressionButton?.state == NSControl.StateValue.on {
                AppEnvironment.current.defaults.set(false, forKey: Constants.UserDefaults.showAlertBeforeClearHistory)
            }
        }

        AppEnvironment.current.clipService.clearAll()
    }

    @objc func selectClipMenuItem(_ sender: NSMenuItem) {
        guard let primaryKey = sender.representedObject as? String else {
            NSSound.beep()
            return
        }
        guard let realm = Realm.safeInstance() else {
            NSSound.beep()
            return
        }
        guard let clip = realm.object(ofType: CPYClip.self, forPrimaryKey: primaryKey) else {
            NSSound.beep()
            return
        }

        AppEnvironment.current.pasteService.paste(with: clip)
    }

    @objc func selectSnippetMenuItem(_ sender: AnyObject) {
        guard let primaryKey = sender.representedObject as? String else {
            NSSound.beep()
            return
        }
        guard let realm = Realm.safeInstance() else {
            NSSound.beep()
            return
        }
        guard let snippet = realm.object(ofType: CPYSnippet.self, forPrimaryKey: primaryKey) else {
            NSSound.beep()
            return
        }
        let processed = SnippetVariableProcessor.process(snippet.content)
        AppEnvironment.current.pasteService.copyToPasteboard(with: processed)
        AppEnvironment.current.pasteService.paste()
    }

    func terminateApplication() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Login Item Methods
    private func promptToAddLoginItems() {
        let alert = NSAlert()
        alert.messageText = L10n.launchClipyOnSystemStartup
        alert.informativeText = L10n.youCanChangeThisSettingInThePreferencesIfYouWant
        alert.addButton(withTitle: L10n.launchOnSystemStartup)
        alert.addButton(withTitle: L10n.donTLaunch)
        alert.showsSuppressionButton = true
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
            AppEnvironment.current.defaults.set(true, forKey: Constants.UserDefaults.loginItem)
            reflectLoginItemState()
        }
        if alert.suppressionButton?.state == NSControl.StateValue.on {
            AppEnvironment.current.defaults.set(true, forKey: Constants.UserDefaults.suppressAlertForLoginItem)
        }
    }

    private func toggleAddingToLoginItems(_ isEnable: Bool) {
        do {
            if isEnable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Failed to update login item: \(error.localizedDescription)")
        }
    }

    private func reflectLoginItemState() {
        let isInLoginItems = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.loginItem)
        toggleAddingToLoginItems(isInLoginItems)
    }
}

// MARK: - NSApplication Delegate
extension AppDelegate: NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Environments
        AppEnvironment.replaceCurrent(environment: AppEnvironment.fromStorage())
        // UserDefaults
        CPYUtilities.registerUserDefaultKeys()
        // Check Accessibility Permission
        AppEnvironment.current.accessibilityService.isAccessibilityEnabled(isPrompt: true)

        // Show Login Item
        if !AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.loginItem) && !AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.suppressAlertForLoginItem) {
            promptToAddLoginItems()
        }

        // Sparkle
        let updater = SUUpdater.shared()
        updater?.feedURL = Constants.Application.appcastURL
        updater?.automaticallyChecksForUpdates = AppEnvironment.current.defaults.bool(forKey: Constants.Update.enableAutomaticCheck)
        updater?.updateCheckInterval = TimeInterval(AppEnvironment.current.defaults.integer(forKey: Constants.Update.checkInterval))

        // Binding Events
        bind()

        // Services
        AppEnvironment.current.clipService.startMonitoring()
        AppEnvironment.current.dataCleanService.startMonitoring()
        AppEnvironment.current.excludeAppService.startMonitoring()
        AppEnvironment.current.hotKeyService.setupDefaultHotKeys()

        // Managers
        AppEnvironment.current.menuManager.setup()

        // Initialize collect mode indicator (observes queue state)
        _ = CollectModeIndicatorController.shared

        // TipKit onboarding — show max one tip per week to avoid overwhelming new users
        try? Tips.configure([.displayFrequency(.weekly)])

        #if DEBUG
        logger.info("Clipy Dev (debug build) launched")
        #else
        logger.info("Clipy launched successfully")
        #endif
    }

}

// MARK: - Bind
private extension AppDelegate {
    func bind() {
        // Login Item
        AppEnvironment.current.defaults
            .publisher(for: \.clipyLoginItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reflectLoginItemState()
            }
            .store(in: &cancellables)

        // Screenshot observation (beta feature)
        let observeScreenshot = AppEnvironment.current.defaults.bool(forKey: Constants.Beta.observerScreenshot)
        if observeScreenshot {
            startScreenshotObservation()
        }

        AppEnvironment.current.defaults
            .publisher(for: \.clipyObserveScreenshot)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                if enabled {
                    self?.startScreenshotObservation()
                } else {
                    self?.screenshotTask?.cancel()
                    self?.screenshotTask = nil
                }
            }
            .store(in: &cancellables)
    }

    func startScreenshotObservation() {
        guard screenshotTask == nil else { return }
        // Monitor pasteboard for screenshot images (simplifies the old Screeen/RxScreeen dependency)
        // Screenshots are already captured via the clipboard monitor in ClipService.
        // This additional observer watches for screenshot files saved to disk.
        screenshotTask = Task { [weak self] in
            let screenshotDir = (NSHomeDirectory() as NSString).appendingPathComponent("Desktop")
            guard let self = self else { return }

            let fileDescriptor = open(screenshotDir, O_EVTONLY)
            guard fileDescriptor >= 0 else { return }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor,
                eventMask: .write,
                queue: .global()
            )

            source.setEventHandler {
                // When a new file appears on Desktop, check if it's a screenshot
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: screenshotDir) {
                    let screenshotFiles = contents.filter { $0.hasPrefix("Screenshot") || $0.hasPrefix("Screen Shot") }
                    if let latest = screenshotFiles.sorted().last {
                        let path = (screenshotDir as NSString).appendingPathComponent(latest)
                        if let image = NSImage(contentsOfFile: path) {
                            DispatchQueue.main.async {
                                AppEnvironment.current.clipService.create(with: image)
                            }
                        }
                    }
                }
            }

            source.setCancelHandler {
                close(fileDescriptor)
            }

            source.resume()

            // Keep alive until cancelled
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
            }
            source.cancel()
        }
    }
}

// MARK: - UserDefaults KVO Bridge
private extension UserDefaults {
    @objc var clipyLoginItem: Bool {
        return bool(forKey: Constants.UserDefaults.loginItem)
    }
    @objc var clipyObserveScreenshot: Bool {
        return bool(forKey: Constants.Beta.observerScreenshot)
    }
}
