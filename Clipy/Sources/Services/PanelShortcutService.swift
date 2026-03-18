//
//  PanelShortcutService.swift
//
//  Clipy
//
//  Manages customizable keyboard shortcuts for the search panel.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Shortcut Definition

struct PanelShortcutDef: Identifiable, Codable, Equatable {
    let id: String
    var key: String        // The character or key name (e.g. "d", "return", "delete")
    var modifiers: UInt    // Raw modifier flags bitmask

    var label: String {
        var parts = [String]()
        let mods = NSEvent.ModifierFlags(rawValue: modifiers)
        if mods.contains(.control) { parts.append("\u{2303}") }
        if mods.contains(.option) { parts.append("\u{2325}") }
        if mods.contains(.shift) { parts.append("\u{21E7}") }
        if mods.contains(.command) { parts.append("\u{2318}") }
        parts.append(keyLabel)
        return parts.joined()
    }

    var keyLabel: String {
        switch key {
        case "return": return "\u{21A9}"
        case "delete", "backspace": return "\u{232B}"
        case "tab": return "\u{21E5}"
        case "space": return "\u{2423}"
        case "escape": return "\u{238B}"
        default: return key.uppercased()
        }
    }
}

// MARK: - Panel Shortcut Service

@MainActor
class PanelShortcutService: ObservableObject {
    static let shared = PanelShortcutService()

    @Published var pin: PanelShortcutDef
    @Published var delete: PanelShortcutDef
    @Published var pastePlain: PanelShortcutDef
    @Published var paste: PanelShortcutDef
    @Published var ocr: PanelShortcutDef
    @Published var share: PanelShortcutDef

    static let defaultPin = PanelShortcutDef(id: "pin", key: "d", modifiers: NSEvent.ModifierFlags.command.rawValue)
    static let defaultDelete = PanelShortcutDef(id: "delete", key: "backspace", modifiers: NSEvent.ModifierFlags.command.rawValue)
    static let defaultPastePlain = PanelShortcutDef(id: "pastePlain", key: "return", modifiers: NSEvent.ModifierFlags.shift.rawValue)
    static let defaultPaste = PanelShortcutDef(id: "paste", key: "return", modifiers: 0)
    static let defaultOCR = PanelShortcutDef(id: "ocr", key: "o", modifiers: NSEvent.ModifierFlags.command.rawValue)
    static let defaultShare = PanelShortcutDef(id: "share", key: "s", modifiers: NSEvent.ModifierFlags.command.rawValue)

    private init() {
        pin = Self.load(key: Constants.PanelShortcuts.pin, fallback: Self.defaultPin)
        delete = Self.load(key: Constants.PanelShortcuts.delete, fallback: Self.defaultDelete)
        pastePlain = Self.load(key: Constants.PanelShortcuts.pastePlain, fallback: Self.defaultPastePlain)
        paste = Self.load(key: Constants.PanelShortcuts.paste, fallback: Self.defaultPaste)
        ocr = Self.load(key: Constants.PanelShortcuts.ocr, fallback: Self.defaultOCR)
        share = Self.load(key: Constants.PanelShortcuts.share, fallback: Self.defaultShare)
    }

    func save(_ shortcut: PanelShortcutDef) {
        let key: String
        switch shortcut.id {
        case "pin": pin = shortcut; key = Constants.PanelShortcuts.pin
        case "delete": delete = shortcut; key = Constants.PanelShortcuts.delete
        case "pastePlain": pastePlain = shortcut; key = Constants.PanelShortcuts.pastePlain
        case "paste": paste = shortcut; key = Constants.PanelShortcuts.paste
        case "ocr": ocr = shortcut; key = Constants.PanelShortcuts.ocr
        case "share": share = shortcut; key = Constants.PanelShortcuts.share
        default: return
        }
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func resetAll() {
        save(Self.defaultPin)
        save(Self.defaultDelete)
        save(Self.defaultPastePlain)
        save(Self.defaultPaste)
        save(Self.defaultOCR)
        save(Self.defaultShare)
    }

    private static func load(key: String, fallback: PanelShortcutDef) -> PanelShortcutDef {
        guard let data = UserDefaults.standard.data(forKey: key),
              let shortcut = try? JSONDecoder().decode(PanelShortcutDef.self, from: data) else {
            return fallback
        }
        return shortcut
    }

    // MARK: - Key Matching

    func matches(_ press: KeyPress, shortcut: PanelShortcutDef) -> Bool {
        let pressedMods = press.modifiers
        let expectedMods = NSEvent.ModifierFlags(rawValue: shortcut.modifiers)

        // Check modifiers match
        let checkCmd = expectedMods.contains(.command) == pressedMods.contains(.command)
        let checkShift = expectedMods.contains(.shift) == pressedMods.contains(.shift)
        let checkOpt = expectedMods.contains(.option) == pressedMods.contains(.option)
        let checkCtrl = expectedMods.contains(.control) == pressedMods.contains(.control)
        guard checkCmd && checkShift && checkOpt && checkCtrl else { return false }

        // Check key
        switch shortcut.key {
        case "return":
            return press.key == .return
        case "delete", "backspace":
            return press.key == .delete || press.key == KeyEquivalent("\u{7F}")
        case "tab":
            return press.key == .tab
        case "escape":
            return press.key == .escape
        case "space":
            return press.key == KeyEquivalent(" ")
        default:
            guard let char = press.characters.first else { return false }
            return String(char).lowercased() == shortcut.key.lowercased()
        }
    }
}
