//
//  ModernPreferencesWindow.swift
//
//  Clipy
//
//  macOS System Settings-style preferences window.
//

import SwiftUI
import Cocoa
import TipKit

// MARK: - Preferences Tab
enum PreferenceTab: String, CaseIterable, Identifiable {
    case general = "General"
    case menu = "Menu"
    case types = "Types"
    case shortcuts = "Shortcuts"
    case excludedApps = "Excluded Apps"
    case updates = "Updates"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .menu: return "list.bullet.rectangle"
        case .types: return "doc.on.clipboard"
        case .shortcuts: return "keyboard"
        case .excludedApps: return "xmark.app"
        case .updates: return "arrow.triangle.2.circlepath"
        }
    }
}

// MARK: - Main Preferences View
struct ModernPreferencesView: View {
    @State private var selectedTab: PreferenceTab = .general

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 2) {
                ForEach(PreferenceTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(selectedTab == tab ? .white : .secondary)
                                .frame(width: 22)
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: selectedTab == tab ? .medium : .regular))
                                .foregroundStyle(selectedTab == tab ? .white : .primary)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedTab == tab ? SwiftUI.Color.accentColor : SwiftUI.Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(12)
            .frame(width: 160)
            .background(.black.opacity(0.02))

            Divider()

            // Content
            Group {
                switch selectedTab {
                case .general:
                    GeneralPreferencesView()
                case .menu:
                    MenuPreferencesView()
                case .types:
                    LegacyPanelView(nibName: "CPYTypePreferenceViewController")
                case .shortcuts:
                    ShortcutsPreferencesView()
                case .excludedApps:
                    LegacyPanelView(nibName: "CPYExcludeAppPreferenceViewController")
                case .updates:
                    UpdatesPreferencesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 440)
    }
}

// MARK: - General Preferences
struct GeneralPreferencesView: View {
    @AppStorage(Constants.UserDefaults.loginItem)
    private var launchAtLogin = false

    @AppStorage(Constants.UserDefaults.inputPasteCommand)
    private var inputPasteCommand = true

    @AppStorage(Constants.UserDefaults.collectCrashReport)
    private var collectCrashReport = true

    @AppStorage(Constants.UserDefaults.maxHistorySize)
    private var maxHistorySize = 30

    @AppStorage(Constants.UserDefaults.reorderClipsAfterPasting)
    private var reorderAfterPasting = true

    @AppStorage(Constants.UserDefaults.showStatusItem)
    private var statusItemStyle = 1

    @AppStorage(Constants.Snippets.useModernPicker)
    private var useModernSnippetPicker = true

    var body: some View {
        Form {
            Section {
                Toggle("Launch Clipy on system startup", isOn: $launchAtLogin)
                Toggle("Input \u{2318}V after selecting a clip", isOn: $inputPasteCommand)
                Toggle("Send crash reports & error logs", isOn: $collectCrashReport)
                Toggle("Use modern snippet picker", isOn: $useModernSnippetPicker)
            } header: {
                Label("Behavior", systemImage: "switch.2")
            }

            Section {
                HStack {
                    Text("Max history size")
                    Spacer()
                    TextField("", value: $maxHistorySize, format: .number)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .popoverTip(HistorySizeTip(), arrowEdge: .leading)
                    Text("items")
                        .foregroundStyle(.secondary)
                }

                Picker("Sort order", selection: $reorderAfterPasting) {
                    Text("Last Used").tag(true)
                    Text("Date Created").tag(false)
                }
            } header: {
                Label("Clipboard History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
            }

            Section {
                Picker("Status bar icon", selection: $statusItemStyle) {
                    Text("Default").tag(1)
                    Text("Light").tag(2)
                    Text("Hidden").tag(0)
                }
            } header: {
                Label("Appearance", systemImage: "paintbrush")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Menu Preferences
struct MenuPreferencesView: View {
    @AppStorage(Constants.UserDefaults.showImageInTheMenu)
    private var showImage = true

    @AppStorage(Constants.UserDefaults.showColorPreviewInTheMenu)
    private var showColorPreview = true

    @AppStorage(Constants.UserDefaults.thumbnailWidth)
    private var thumbnailWidth = 100

    @AppStorage(Constants.UserDefaults.thumbnailHeight)
    private var thumbnailHeight = 32

    @AppStorage(Constants.UserDefaults.showIconInTheMenu)
    private var showIcons = true

    @AppStorage(Constants.UserDefaults.addNumericKeyEquivalents)
    private var addKeyEquivalents = false

    @AppStorage(Constants.UserDefaults.menuItemsAreMarkedWithNumbers)
    private var markWithNumbers = true

    @AppStorage(Constants.UserDefaults.menuItemsTitleStartWithZero)
    private var startWithZero = false

    @AppStorage(Constants.UserDefaults.maxMenuItemTitleLength)
    private var maxTitleLength = 20

    @AppStorage(Constants.UserDefaults.numberOfItemsPlaceInline)
    private var itemsInline = 0

    @AppStorage(Constants.UserDefaults.numberOfItemsPlaceInsideFolder)
    private var itemsInFolder = 10

    @AppStorage(Constants.UserDefaults.copySameHistory)
    private var copySameHistory = true

    @AppStorage(Constants.UserDefaults.overwriteSameHistory)
    private var overwriteSameHistory = true

    @AppStorage(Constants.UserDefaults.addClearHistoryMenuItem)
    private var addClearMenuItem = true

    @AppStorage(Constants.UserDefaults.showAlertBeforeClearHistory)
    private var showClearAlert = true

    @AppStorage(Constants.UserDefaults.clearHistoryIncludesPinned)
    private var clearIncludesPinned = false

    @AppStorage(Constants.UserDefaults.showToolTipOnMenuItem)
    private var showToolTip = true

    @AppStorage(Constants.UserDefaults.maxLengthOfToolTip)
    private var maxToolTipLength = 200

    var body: some View {
        Form {
            Section {
                Toggle("Show image thumbnails", isOn: $showImage)
                if showImage {
                    HStack {
                        Text("Thumbnail size")
                        Spacer()
                        TextField("W", value: $thumbnailWidth, format: .number)
                            .frame(width: 50)
                            .textFieldStyle(.roundedBorder)
                        Text("\u{00D7}")
                            .foregroundStyle(.secondary)
                        TextField("H", value: $thumbnailHeight, format: .number)
                            .frame(width: 50)
                            .textFieldStyle(.roundedBorder)
                        Text("px")
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle("Show color code preview", isOn: $showColorPreview)
                Toggle("Show folder icons", isOn: $showIcons)
            } header: {
                Label("Display", systemImage: "eye")
            }

            Section {
                Toggle("Number menu items", isOn: $markWithNumbers)
                if markWithNumbers {
                    Toggle("Start numbering from 0", isOn: $startWithZero)
                }
                Toggle("Add keyboard shortcuts (0\u{2013}9)", isOn: $addKeyEquivalents)
            } header: {
                Label("Numbering", systemImage: "number")
            }

            Section {
                HStack {
                    Text("Characters per item")
                    Spacer()
                    TextField("", value: $maxTitleLength, format: .number)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Items shown inline")
                    Spacer()
                    TextField("", value: $itemsInline, format: .number)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Items per folder")
                    Spacer()
                    TextField("", value: $itemsInFolder, format: .number)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Label("Layout", systemImage: "rectangle.3.group")
            }

            Section {
                Toggle("Move duplicate clips to top", isOn: $copySameHistory)
                if copySameHistory {
                    Toggle("Overwrite instead of duplicate", isOn: $overwriteSameHistory)
                }
            } header: {
                Label("Duplicates", systemImage: "doc.on.doc")
            }

            Section {
                Toggle("Show tooltip on hover", isOn: $showToolTip)
                if showToolTip {
                    HStack {
                        Text("Max tooltip length")
                        Spacer()
                        TextField("", value: $maxToolTipLength, format: .number)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                        Text("chars")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Label("Tooltips", systemImage: "text.bubble")
            }

            Section {
                Toggle("Show \"Clear History\" in menu", isOn: $addClearMenuItem)
                if addClearMenuItem {
                    Toggle("Confirm before clearing", isOn: $showClearAlert)
                }
                Toggle("Also clear pinned items", isOn: $clearIncludesPinned)
            } header: {
                Label("Clear History", systemImage: "trash")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Updates Preferences
struct UpdatesPreferencesView: View {
    @AppStorage(Constants.Update.enableAutomaticCheck)
    private var autoCheck = true

    @AppStorage(Constants.Update.checkInterval)
    private var checkInterval = 86400

    var body: some View {
        Form {
            Section {
                Toggle("Check for updates automatically", isOn: $autoCheck)

                if autoCheck {
                    Picker("Check interval", selection: $checkInterval) {
                        Text("Every hour").tag(3600)
                        Text("Every 6 hours").tag(21600)
                        Text("Daily").tag(86400)
                        Text("Weekly").tag(604800)
                    }
                }
            } header: {
                Label("Software Updates", systemImage: "arrow.triangle.2.circlepath")
            }

            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.appVersion ?? "Unknown")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("About", systemImage: "info.circle")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Legacy Panel Wrapper
struct LegacyPanelView: NSViewControllerRepresentable {
    let nibName: String

    func makeNSViewController(context: Context) -> NSViewController {
        switch nibName {
        case "CPYTypePreferenceViewController":
            return CPYTypePreferenceViewController(nibName: nibName, bundle: nil)
        case "CPYShortcutsPreferenceViewController":
            return CPYShortcutsPreferenceViewController(nibName: nibName, bundle: nil)
        case "CPYExcludeAppPreferenceViewController":
            return CPYExcludeAppPreferenceViewController(nibName: nibName, bundle: nil)
        default:
            return NSViewController(nibName: nibName, bundle: nil)
        }
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}
}

// MARK: - Shortcuts Preferences

struct ShortcutsPreferencesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Global Hotkeys — legacy XIB (has its own internal 44px left margin)
                VStack(alignment: .leading, spacing: 6) {
                    Label("Global Hotkeys", systemImage: "globe")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 56)

                    LegacyPanelView(nibName: "CPYShortcutsPreferenceViewController")
                        .frame(maxWidth: .infinity)
                        .frame(height: 275)
                }

                Divider()
                    .padding(.horizontal, 56)

                // Panel Shortcuts — native SwiftUI
                VStack(alignment: .leading, spacing: 10) {
                    Label("Search Panel Shortcuts", systemImage: "keyboard")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 56)

                    PanelShortcutsList()
                        .padding(.horizontal, 56)
                }
                .popoverTip(CustomizeShortcutsTip(), arrowEdge: .leading)
            }
            .padding(.vertical, 12)
        }
    }
}

struct PanelShortcutsList: View {
    @ObservedObject private var service = PanelShortcutService.shared

    var body: some View {
        ShortcutRow(name: "Paste clip", shortcut: service.paste, onRecord: { service.save($0) })
        ShortcutRow(name: "Paste as plain text", shortcut: service.pastePlain, onRecord: { service.save($0) })
        ShortcutRow(name: "Toggle pin", shortcut: service.pin, onRecord: { service.save($0) })
        ShortcutRow(name: "Delete clip", shortcut: service.delete, onRecord: { service.save($0) })

        HStack {
            Spacer()
            Button("Reset to Defaults") {
                service.resetAll()
            }
            .controlSize(.small)
        }
    }
}

struct ShortcutRow: View {
    let name: String
    let shortcut: PanelShortcutDef
    let onRecord: (PanelShortcutDef) -> Void

    @State private var isRecording = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text(name)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isRecording {
                Text("Press shortcut...")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .focusable()
                    .focused($isFocused)
                    .onKeyPress(phases: .down) { press in
                        // Ignore lone modifier presses
                        if press.characters.isEmpty && press.key != .return && press.key != .delete && press.key != .tab && press.key != .escape {
                            return .ignored
                        }
                        let key = resolveKey(press)
                        let mods = resolveModifiers(press)
                        let updated = PanelShortcutDef(id: shortcut.id, key: key, modifiers: mods)
                        onRecord(updated)
                        isRecording = false
                        return .handled
                    }
                    .onAppear { isFocused = true }

                Button("Cancel") {
                    isRecording = false
                }
                .controlSize(.small)
            } else {
                Button {
                    isRecording = true
                } label: {
                    Text(shortcut.label)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(.primary.opacity(0.15), lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func resolveKey(_ press: KeyPress) -> String {
        switch press.key {
        case .return: return "return"
        case .delete: return "delete"
        case .tab: return "tab"
        case .escape: return "escape"
        case KeyEquivalent("\u{7F}"): return "backspace"
        case KeyEquivalent(" "): return "space"
        default:
            if let char = press.characters.first {
                return String(char).lowercased()
            }
            return ""
        }
    }

    private func resolveModifiers(_ press: KeyPress) -> UInt {
        var flags = NSEvent.ModifierFlags()
        if press.modifiers.contains(.command) { flags.insert(.command) }
        if press.modifiers.contains(.shift) { flags.insert(.shift) }
        if press.modifiers.contains(.option) { flags.insert(.option) }
        if press.modifiers.contains(.control) { flags.insert(.control) }
        return flags.rawValue
    }
}

// MARK: - Modern Preferences Window Controller
class ModernPreferencesWindowController: NSWindowController {
    static let shared = ModernPreferencesWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: true
        )
        window.title = "Clipy Settings"
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = false
        window.center()
        window.collectionBehavior = .canJoinAllSpaces

        super.init(window: window)

        window.contentView = NSHostingView(rootView: ModernPreferencesView())
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Window Delegate
extension ModernPreferencesWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Save type preferences if the types tab was active
        if let window = window, !window.makeFirstResponder(window) {
            window.endEditing(for: nil)
        }
        NSApp.deactivate()
    }
}
