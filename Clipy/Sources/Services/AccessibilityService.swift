//
//  AccessibilityService.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//
//  Created by Econa77 on 2018/10/03.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation
import Cocoa
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy", category: "Accessibility")

final class AccessibilityService {
    private var hasShownAlertThisSession = false
}

// MARK: - Permission
extension AccessibilityService {
    @discardableResult
    func isAccessibilityEnabled(isPrompt: Bool) -> Bool {
        let checkOptionPromptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [checkOptionPromptKey: isPrompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    func showAccessibilityAuthenticationAlert() {
        // Only show once per session to avoid alert loops
        guard !hasShownAlertThisSession else {
            logger.warning("Accessibility not granted — alert already shown this session")
            return
        }
        hasShownAlertThisSession = true

        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "Clipy needs Accessibility access to paste clipboard items. Please add Clipy in System Settings → Privacy & Security → Accessibility."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
            openAccessibilitySettingWindow()
        }
    }

    @discardableResult
    func openAccessibilitySettingWindow() -> Bool {
        // Modern macOS System Settings URL
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return false }
        return NSWorkspace.shared.open(url)
    }
}
