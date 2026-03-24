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
import RealmSwift

// MARK: - Preferences Tab
enum PreferenceTab: String, Identifiable {
    case general = "General"
    case menu = "Menu"
    case types = "Types"
    case shortcuts = "Shortcuts"
    case excludedApps = "Excluded Apps"
    case updates = "Updates"
    case developer = "Developer"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .menu: return "list.bullet.rectangle"
        case .types: return "doc.on.clipboard"
        case .shortcuts: return "keyboard"
        case .excludedApps: return "xmark.app"
        case .updates: return "arrow.triangle.2.circlepath"
        case .developer: return "hammer"
        }
    }

    /// Tabs visible by default (developer tab requires dev mode)
    static var visibleTabs: [PreferenceTab] {
        var tabs: [PreferenceTab] = [.general, .menu, .types, .shortcuts, .excludedApps, .updates]
        if UserDefaults.standard.bool(forKey: Constants.Developer.devModeEnabled) {
            tabs.append(.developer)
        }
        return tabs
    }
}

// MARK: - Main Preferences View
struct ModernPreferencesView: View {
    @State private var selectedTab: PreferenceTab = .general
    @AppStorage(Constants.Developer.devModeEnabled) private var devMode = false

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 2) {
                ForEach(PreferenceTab.visibleTabs) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(selectedTab == tab ? .white : tab == .developer ? .orange : .secondary)
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

                if devMode {
                    DevClippyView()
                        .padding(.bottom, 4)
                }
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
                    ClipboardTypesPreferencesView()
                case .shortcuts:
                    ShortcutsPreferencesView()
                case .excludedApps:
                    ExcludedAppsPreferencesView()
                case .updates:
                    UpdatesPreferencesView()
                case .developer:
                    DeveloperPreferencesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 440)
        .onChange(of: devMode) { _, enabled in
            if !enabled && selectedTab == .developer {
                selectedTab = .general
            }
        }
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

    @AppStorage(Constants.Developer.devModeEnabled)
    private var devMode = false

    @State private var showDevWarning = false

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

            Section {
                HStack(spacing: 10) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("Developer Mode", isOn: Binding(
                            get: { devMode },
                            set: { newValue in
                                if newValue { showDevWarning = true }
                                else { devMode = false }
                            }
                        ))
                        .font(.system(size: 12, weight: .medium))
                        Text("Unlocks the Developer tab with debug tools, tip management, and database info.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .alert("Enable Developer Mode?", isPresented: $showDevWarning) {
                    Button("Cancel", role: .cancel) {}
                    Button("Enable") { devMode = true }
                } message: {
                    Text("With great power comes great responsibility... and occasionally a corrupted database. You've been warned.")
                }
            } header: {
                Label("Advanced", systemImage: "wrench.and.screwdriver")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Dev Clippy Easter Egg
struct DevClippyView: View {
    @State private var bounce = false
    @State private var noteIndex = 0

    private let notes = ["music.note", "music.quarternote.3", "music.note.list", "music.mic"]

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Clippy body — a paperclip vibing
                Image(systemName: "paperclip")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.orange.opacity(0.6))
                    .rotationEffect(.degrees(bounce ? -8 : 8))

                // Headphones
                Image(systemName: "headphones")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.orange.opacity(0.8))
                    .offset(x: 0, y: -14)

                // Floating music note
                Image(systemName: notes[noteIndex])
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.purple.opacity(0.6))
                    .offset(x: bounce ? 14 : 10, y: bounce ? -22 : -18)
                    .scaleEffect(bounce ? 1.2 : 0.8)
            }
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: bounce)

            Text("vibing...")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.quaternary)
        }
        .onAppear {
            bounce = true
            // Cycle through music notes
            Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    noteIndex = (noteIndex + 1) % notes.count
                }
            }
        }
        .frame(height: 50)
    }
}

// MARK: - Developer Preferences
struct DeveloperPreferencesView: View {
    @AppStorage(Constants.Developer.hotkeysDisabled) private var hotkeysDisabled = false
    @State private var realmPath = ""
    @State private var realmSize = ""
    @State private var clipCount = 0
    @State private var folderCount = 0
    @State private var snippetCount = 0
    @State private var showResetTipsConfirm = false
    @State private var showClearHistoryConfirm = false
    @State private var tipStatus = "Normal"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Developer Tools")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Here be dragons. Handle with care.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                // TipKit Management
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Onboarding Tips", systemImage: "lightbulb")
                            .font(.system(size: 13, weight: .semibold))

                        HStack(spacing: 8) {
                            Text("Status:")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(tipStatus)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.green)
                        }

                        HStack(spacing: 8) {
                            Button("Reset All Tips") {
                                showResetTipsConfirm = true
                            }
                            .alert("Reset all tips?", isPresented: $showResetTipsConfirm) {
                                Button("Cancel", role: .cancel) {}
                                Button("Reset") { resetTips() }
                            } message: {
                                Text("All onboarding tips will appear again as if the app was freshly installed.")
                            }

                            Button("Show All Tips Now") {
                                showAllTips()
                            }

                            Button("Hide All Tips") {
                                hideAllTips()
                            }
                        }

                        Text("Reset tips to test onboarding flow. \"Show All\" forces all tips to display immediately.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(8)
                }
                .padding(.horizontal, 24)

                // Database Info
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Realm Database", systemImage: "cylinder.split.1x2")
                            .font(.system(size: 13, weight: .semibold))

                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                            GridRow {
                                Text("Path:").font(.system(size: 11)).foregroundStyle(.secondary)
                                Text(realmPath)
                                    .font(.system(size: 10, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)
                            }
                            GridRow {
                                Text("Size:").font(.system(size: 11)).foregroundStyle(.secondary)
                                Text(realmSize).font(.system(size: 11, design: .monospaced))
                            }
                            GridRow {
                                Text("Clips:").font(.system(size: 11)).foregroundStyle(.secondary)
                                Text("\(clipCount)").font(.system(size: 11, design: .monospaced))
                            }
                            GridRow {
                                Text("Folders:").font(.system(size: 11)).foregroundStyle(.secondary)
                                Text("\(folderCount)").font(.system(size: 11, design: .monospaced))
                            }
                            GridRow {
                                Text("Snippets:").font(.system(size: 11)).foregroundStyle(.secondary)
                                Text("\(snippetCount)").font(.system(size: 11, design: .monospaced))
                            }
                        }

                        HStack(spacing: 8) {
                            Button("Reveal in Finder") {
                                let url = URL(fileURLWithPath: realmPath)
                                NSWorkspace.shared.selectFile(realmPath, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                            }

                            Button("Refresh") { loadDatabaseInfo() }
                        }
                    }
                    .padding(8)
                }
                .padding(.horizontal, 24)

                // Shortcuts
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Panel Shortcuts", systemImage: "keyboard")
                            .font(.system(size: 13, weight: .semibold))

                        Button("Reset All Shortcuts to Defaults") {
                            PanelShortcutService.shared.resetAll()
                        }

                        Text("Restores Paste (\u{21A9}), Plain Text (\u{21E7}\u{21A9}), Pin (\u{2318}D), Delete (\u{2318}\u{232B}), OCR (\u{2318}O), Share (\u{2318}S)")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(8)
                }
                .padding(.horizontal, 24)

                // Global Hotkeys Toggle
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Global Hotkeys", systemImage: "globe")
                            .font(.system(size: 13, weight: .semibold))

                        HStack(spacing: 16) {
                            hotKeyOptionButton(
                                label: "Enabled",
                                icon: "keyboard",
                                color: .green,
                                isSelected: !hotkeysDisabled
                            ) {
                                hotkeysDisabled = false
                                AppEnvironment.current.hotKeyService.enableAllHotKeys()
                            }

                            hotKeyOptionButton(
                                label: "Disabled",
                                icon: "keyboard.badge.ellipsis",
                                color: .orange,
                                isSelected: hotkeysDisabled
                            ) {
                                hotkeysDisabled = true
                                AppEnvironment.current.hotKeyService.disableAllHotKeys()
                            }
                        }

                        Text("Disable hotkeys to run Clipy Dev alongside the release build without conflicts.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(8)
                }
                .padding(.horizontal, 24)

                // Danger Zone
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Danger Zone", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.red)

                        Button("Clear All Clipboard History", role: .destructive) {
                            showClearHistoryConfirm = true
                        }
                        .alert("Clear all history?", isPresented: $showClearHistoryConfirm) {
                            Button("Cancel", role: .cancel) {}
                            Button("Clear Everything", role: .destructive) { clearAllHistory() }
                        } message: {
                            Text("This will permanently delete all clipboard history. Snippets will not be affected.")
                        }

                        Text("Permanently removes all clips. Snippets and folders are preserved.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(8)
                }
                .padding(.horizontal, 24)

                // Stats for Nerds
                GroupBox {
                    StatsForNerdsView()
                        .padding(8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
        .onAppear { loadDatabaseInfo() }
    }

    // MARK: - Hotkey Option Button

    private func hotKeyOptionButton(label: String, icon: String, color: SwiftUI.Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? color : .secondary)
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? color : .secondary)
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.1) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? color.opacity(0.3) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func resetTips() {
        try? Tips.resetDatastore()
        try? Tips.configure([.displayFrequency(.immediate)])
        tipStatus = "Reset — all tips will show again"
    }

    private func showAllTips() {
        try? Tips.resetDatastore()
        try? Tips.configure([.displayFrequency(.immediate)])
        Tips.showAllTipsForTesting()
        tipStatus = "Showing all tips"
    }

    private func hideAllTips() {
        Tips.hideAllTipsForTesting()
        tipStatus = "All tips hidden"
    }

    private func loadDatabaseInfo() {
        if let url = Realm.Configuration.defaultConfiguration.fileURL {
            realmPath = url.path
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int {
                realmSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            }
        }
        if let realm = Realm.safeInstance() {
            clipCount = realm.objects(CPYClip.self).count
            folderCount = realm.objects(CPYFolder.self).count
            snippetCount = realm.objects(CPYSnippet.self).count
        }
    }

    private func clearAllHistory() {
        guard let realm = Realm.safeInstance() else { return }
        let clips = realm.objects(CPYClip.self)
        // Delete data files
        clips.forEach { clip in
            try? FileManager.default.removeItem(atPath: clip.dataPath)
        }
        realm.transaction { realm.delete(clips) }
        loadDatabaseInfo()
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

// MARK: - Stats for Nerds
struct StatsForNerdsView: View {
    @ObservedObject private var metrics = UsageMetricsService.shared
    @State private var showResetConfirm = false
    @State private var showExportSuccess = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Label("Stats for Nerds", systemImage: "chart.bar.xaxis")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(totalActions) total actions")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            // Radar Chart — Feature Usage
            VStack(alignment: .leading, spacing: 6) {
                Text("Feature Radar")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                RadarChartView(data: radarData)
                    .frame(height: 180)
            }

            // Hourly Activity
            VStack(alignment: .leading, spacing: 6) {
                Text("Activity by Hour")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                HourlyBarChart(data: metrics.hourlyHistogram)
                    .frame(height: 60)
            }

            // Daily Activity (last 14 days)
            VStack(alignment: .leading, spacing: 6) {
                Text("Last 14 Days")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                DailyBarChart(data: recentDailyData)
                    .frame(height: 60)
            }

            // Top Features Table
            VStack(alignment: .leading, spacing: 4) {
                Text("Event Counters")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                let sorted = metrics.counters.sorted { $0.value > $1.value }
                ForEach(sorted.prefix(10), id: \.key) { key, value in
                    HStack {
                        Text(friendlyName(for: key))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(value)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                }
            }

            // Actions
            HStack(spacing: 8) {
                Button("Export JSON") { exportMetrics() }
                    .controlSize(.small)
                Button("Reset") { showResetConfirm = true }
                    .controlSize(.small)
                    .foregroundStyle(.red)
                if showExportSuccess {
                    Text("Saved!")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
            }
            .alert("Reset all metrics?", isPresented: $showResetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) { metrics.reset() }
            }
        }
    }

    // MARK: - Computed Data

    private var totalActions: Int {
        metrics.counters.values.reduce(0, +)
    }

    private var radarData: [(label: String, value: Double)] {
        let features: [(String, String)] = [
            ("Paste", "pasteFromPanel"),
            ("Search", "searchPerformed"),
            ("OCR", "ocrUsed"),
            ("Pin", "pinToggled"),
            ("Share", "shareUsed"),
            ("Queue", "queueUsed"),
            ("Vault", "vaultUnlocked"),
            ("Snippets", "snippetPasted"),
            ("Plain Text", "pastePlainText"),
            ("URL Clean", "urlCleaned"),
            ("JSON", "jsonFormatted"),
            ("Transform", "textTransformed"),
        ]
        let maxVal = max(1.0, Double(metrics.counters.values.max() ?? 1))
        return features.map { (label: $0.0, value: Double(metrics.counters[$0.1] ?? 0) / maxVal) }
    }

    private var recentDailyData: [(day: String, count: Int)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "dd"

        return (0..<14).reversed().map { daysAgo in
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
            let key = formatter.string(from: date)
            let label = shortFormatter.string(from: date)
            return (day: label, count: metrics.dailyActivity[key] ?? 0)
        }
    }

    private func friendlyName(for key: String) -> String {
        switch key {
        case "clipsCopied": return "Clips copied"
        case "pasteFromPanel": return "Paste (panel)"
        case "pasteFromMenu": return "Paste (menu)"
        case "pasteFromHotkey": return "Paste (hotkey)"
        case "pastePlainText": return "Plain text"
        case "searchPerformed": return "Searches"
        case "ocrUsed": return "OCR"
        case "pinToggled": return "Pin toggle"
        case "shareUsed": return "Share"
        case "queueUsed": return "Queue paste"
        case "vaultUnlocked": return "Vault unlock"
        case "snippetPasted": return "Snippets"
        case "urlCleaned": return "URL clean"
        case "jsonFormatted": return "JSON format"
        case "textTransformed": return "Text transform"
        default: return key
        }
    }

    private func exportMetrics() {
        guard let data = metrics.exportJSON() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "clipy-metrics-\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url)
        withAnimation { showExportSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showExportSuccess = false }
        }
    }
}

// MARK: - Radar Chart
struct RadarChartView: View {
    let data: [(label: String, value: Double)]

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius: CGFloat = min(geo.size.width, geo.size.height) / 2 - 30
            Canvas { context, _ in
                let count = data.count
                guard !data.isEmpty else { return }
                let step: Double = (2 * .pi) / Double(count)

                // Grid rings
                for ring in [0.25, 0.5, 0.75, 1.0] {
                    var gridPath = Path()
                    for idx in 0..<count {
                        let ang: Double = step * Double(idx) - .pi / 2
                        let pt = CGPoint(x: center.x + cos(ang) * radius * ring, y: center.y + sin(ang) * radius * ring)
                        if idx == 0 { gridPath.move(to: pt) } else { gridPath.addLine(to: pt) }
                    }
                    gridPath.closeSubpath()
                    context.stroke(gridPath, with: .color(.white.opacity(0.06)), lineWidth: 0.5)
                }

                // Axis lines
                for idx in 0..<count {
                    let ang: Double = step * Double(idx) - .pi / 2
                    var axisPath = Path()
                    axisPath.move(to: center)
                    axisPath.addLine(to: CGPoint(x: center.x + cos(ang) * radius, y: center.y + sin(ang) * radius))
                    context.stroke(axisPath, with: .color(.white.opacity(0.04)), lineWidth: 0.5)
                }

                // Data polygon
                var dataPath = Path()
                for idx in 0..<count {
                    let ang: Double = step * Double(idx) - .pi / 2
                    let val: Double = max(0.02, data[idx].value)
                    let pt = CGPoint(x: center.x + cos(ang) * radius * val, y: center.y + sin(ang) * radius * val)
                    if idx == 0 { dataPath.move(to: pt) } else { dataPath.addLine(to: pt) }
                }
                dataPath.closeSubpath()
                context.fill(dataPath, with: .color(.orange.opacity(0.15)))
                context.stroke(dataPath, with: .color(.orange), lineWidth: 1.5)

                // Data points
                for idx in 0..<count {
                    let ang: Double = step * Double(idx) - .pi / 2
                    let val: Double = max(0.02, data[idx].value)
                    let pt = CGPoint(x: center.x + cos(ang) * radius * val, y: center.y + sin(ang) * radius * val)
                    context.fill(Circle().path(in: CGRect(x: pt.x - 2, y: pt.y - 2, width: 4, height: 4)), with: .color(.orange))
                }
            }

            // Labels as SwiftUI Text (outside Canvas for proper rendering)
            ForEach(0..<data.count, id: \.self) { idx in
                radarLabel(idx: idx, center: center, radius: radius)
            }
        }
    }

    private func radarLabel(idx: Int, center: CGPoint, radius: CGFloat) -> some View {
        let count = data.count
        let step: Double = (2 * .pi) / Double(count)
        let ang: Double = step * Double(idx) - .pi / 2
        let labelR: CGFloat = radius + 18
        return Text(data[idx].label)
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(.secondary)
            .position(x: center.x + cos(ang) * labelR, y: center.y + sin(ang) * labelR)
    }
}

// MARK: - Hourly Bar Chart
struct HourlyBarChart: View {
    let data: [Int]

    var body: some View {
        let maxVal = max(1, data.max() ?? 1)
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(0..<24, id: \.self) { hour in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(barColor(for: hour))
                            .frame(height: max(1, geo.size.height * CGFloat(data[hour]) / CGFloat(maxVal)))
                        if hour % 6 == 0 {
                            Text("\(hour)")
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    private func barColor(for hour: Int) -> SwiftUI.Color {
        if hour >= 9 && hour < 18 { return .orange.opacity(0.7) }
        if hour >= 6 && hour < 22 { return .orange.opacity(0.4) }
        return .orange.opacity(0.2)
    }
}

// MARK: - Daily Bar Chart
struct DailyBarChart: View {
    let data: [(day: String, count: Int)]

    var body: some View {
        let maxVal = max(1, data.map(\.count).max() ?? 1)
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.blue.opacity(item.count >= 1 ? 0.6 : 0.1))
                            .frame(height: max(2, geo.size.height * CGFloat(item.count) / CGFloat(maxVal)))
                        Text(item.day)
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

// MARK: - Clipboard Types Preferences
struct ClipboardTypeItem: Identifiable {
    let id: String
    let label: String
    let icon: String
    let desc: String
}

private let clipboardTypes: [ClipboardTypeItem] = [
    ClipboardTypeItem(id: "String", label: "Plain Text", icon: "doc.plaintext", desc: "Basic text content from any app"),
    ClipboardTypeItem(id: "RTF", label: "Rich Text (RTF)", icon: "doc.richtext", desc: "Formatted text with fonts, colors, and styles"),
    ClipboardTypeItem(id: "RTFD", label: "Rich Text Directory (RTFD)", icon: "doc.richtext.fill", desc: "Rich text with embedded images and attachments"),
    ClipboardTypeItem(id: "PDF", label: "PDF", icon: "doc.fill", desc: "PDF documents and page content"),
    ClipboardTypeItem(id: "Filenames", label: "File References", icon: "doc.on.doc", desc: "Copied file and folder paths from Finder"),
    ClipboardTypeItem(id: "URL", label: "URLs", icon: "link", desc: "Web addresses and links"),
    ClipboardTypeItem(id: "TIFF", label: "Images", icon: "photo", desc: "Screenshots, copied images, and graphics"),
]

struct ClipboardTypesPreferencesView: View {
    @State private var storeTypes: [String: Bool] = [:]

    var body: some View {
        Form {
            Section {
                ForEach(clipboardTypes) { type in
                    HStack(spacing: 10) {
                        Image(systemName: type.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Toggle(isOn: binding(for: type.id)) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(type.label)
                                    .font(.system(size: 12, weight: .medium))
                                Text(type.desc)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            } header: {
                Label("Clipboard types to monitor", systemImage: "doc.on.clipboard")
            } footer: {
                Text("Unchecked types will be ignored when copying. At least one type must be enabled.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear { loadTypes() }
    }

    private func binding(for key: String) -> Binding<Bool> {
        Binding(
            get: { storeTypes[key] ?? true },
            set: { newValue in
                storeTypes[key] = newValue
                // Prevent disabling all types
                if !storeTypes.values.contains(true) {
                    storeTypes[key] = true
                    return
                }
                saveTypes()
            }
        )
    }

    private func loadTypes() {
        if let dict = UserDefaults.standard.object(forKey: Constants.UserDefaults.storeTypes) as? [String: NSNumber] {
            storeTypes = dict.mapValues { $0.boolValue }
        } else {
            // Default: all enabled
            clipboardTypes.forEach { storeTypes[$0.id] = true }
        }
    }

    private func saveTypes() {
        let nsDict = storeTypes.mapValues { NSNumber(value: $0) }
        UserDefaults.standard.set(nsDict, forKey: Constants.UserDefaults.storeTypes)
    }
}

// MARK: - Excluded Apps Preferences
struct ExcludedAppsPreferencesView: View {
    @State private var apps: [CPYAppInfo] = []
    @State private var selectedApp: CPYAppInfo?

    var body: some View {
        Form {
            Section {
                if apps.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "app.dashed")
                                .font(.system(size: 24))
                                .foregroundStyle(.quaternary)
                            Text("No excluded apps")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                            Text("Clips copied from excluded apps will be ignored.")
                                .font(.system(size: 10))
                                .foregroundStyle(.quaternary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                } else {
                    ForEach(apps, id: \.identifier) { app in
                        HStack(spacing: 10) {
                            if let icon = NSWorkspace.shared.icon(forFile: "/Applications/\(app.name).app") as NSImage? {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "app.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.name)
                                    .font(.system(size: 12, weight: .medium))
                                Text(app.identifier)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Button {
                                AppEnvironment.current.excludeAppService.delete(with: app)
                                loadApps()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } header: {
                HStack {
                    Label("Excluded Applications", systemImage: "xmark.app")
                    Spacer()
                    Button {
                        addApp()
                    } label: {
                        Label("Add App", systemImage: "plus")
                            .font(.system(size: 11))
                    }
                    .controlSize(.small)
                }
            } footer: {
                Text("Clipboard content copied from these apps will not be recorded in history.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear { loadApps() }
    }

    private func loadApps() {
        apps = AppEnvironment.current.excludeAppService.applications
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true
        panel.prompt = "Add"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK else { return }
        panel.urls.forEach { url in
            guard let bundle = Bundle(url: url), let info = bundle.infoDictionary else { return }
            guard let appInfo = CPYAppInfo(info: info as [String: AnyObject]) else { return }
            AppEnvironment.current.excludeAppService.add(with: appInfo)
        }
        loadApps()
    }
}

// MARK: - Updates Preferences
// MARK: - Update State
enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate
    case available(version: String, downloadURL: String)
    case downloading(progress: Double)
    case installing
    case failed(message: String)
}

struct UpdatesPreferencesView: View {
    @State private var state: UpdateState = .idle
    @State private var latestVersion: String?

    private let currentVersion = Bundle.main.appVersion ?? "Unknown"
    private let repoAPI = "https://api.github.com/repos/jeanluciradukunda/Clipy/releases/latest"

    var body: some View {
        Form {
            Section {
                // Current version
                HStack {
                    Text("Current version")
                    Spacer()
                    Text(currentVersion)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                // Status row
                statusView

                // Action buttons
                actionButtons
            } header: {
                Label("Software Updates", systemImage: "arrow.triangle.2.circlepath")
            } footer: {
                Text("Updates are downloaded from GitHub Releases and installed automatically.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear { checkForUpdates() }
    }

    // MARK: - Status View

    @ViewBuilder
    private var statusView: some View {
        switch state {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking for updates...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        case .upToDate:
            HStack {
                Label("You're up to date", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
                Spacer()
                Text(currentVersion)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        case .available(let version, _):
            HStack {
                Label("Update available", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                Spacer()
                Text("\(currentVersion) → \(version)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.orange)
            }
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Downloading update...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            }
        case .installing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Installing update...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        case .failed(let message):
            HStack {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        HStack {
            switch state {
            case .idle, .upToDate, .failed:
                Button("Check for Updates") { checkForUpdates() }
            case .checking:
                Button("Check for Updates") {}.disabled(true)
            case .available(_, let url):
                Button("Update Now") { downloadAndInstall(from: url) }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            case .downloading:
                Button("Downloading...") {}.disabled(true)
            case .installing:
                Button("Installing...") {}.disabled(true)
            }

            Spacer()

            Button("View Releases") {
                NSWorkspace.shared.open(URL(string: "https://github.com/jeanluciradukunda/Clipy/releases")!)
            }
        }
    }

    // MARK: - Check

    private func checkForUpdates() {
        state = .checking
        Task {
            do {
                let url = URL(string: repoAPI)!
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    await MainActor.run { state = .failed(message: "Could not parse release info") }
                    return
                }

                let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

                // Find .dmg asset URL
                var dmgURL: String?
                if let assets = json["assets"] as? [[String: Any]] {
                    dmgURL = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".dmg") == true })?["browser_download_url"] as? String
                }

                await MainActor.run {
                    latestVersion = version
                    if version == currentVersion {
                        state = .upToDate
                    } else if let dmgURL {
                        state = .available(version: version, downloadURL: dmgURL)
                    } else {
                        state = .failed(message: "No .dmg found in release")
                    }
                }
            } catch {
                await MainActor.run { state = .failed(message: "Network error: \(error.localizedDescription)") }
            }
        }
    }

    // MARK: - Download & Install

    private func downloadAndInstall(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        state = .downloading(progress: 0)

        Task {
            do {
                // Download with progress
                let (tempURL, _) = try await URLSession.shared.download(from: url, delegate: nil)
                let dmgPath = FileManager.default.temporaryDirectory.appendingPathComponent("Clipy-update.dmg")
                try? FileManager.default.removeItem(at: dmgPath)
                try FileManager.default.moveItem(at: tempURL, to: dmgPath)

                await MainActor.run { state = .installing }

                // Mount DMG
                let mountProcess = Process()
                mountProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                mountProcess.arguments = ["attach", dmgPath.path, "-nobrowse", "-quiet"]
                let mountPipe = Pipe()
                mountProcess.standardOutput = mountPipe
                try mountProcess.run()
                mountProcess.waitUntilExit()

                // Find mounted volume
                let volumePath = try FileManager.default.contentsOfDirectory(atPath: "/Volumes")
                    .first(where: { $0.hasPrefix("Clipy") })
                    .map { "/Volumes/\($0)" }

                guard let volume = volumePath else {
                    await MainActor.run { state = .failed(message: "Could not mount DMG") }
                    return
                }

                // Find .app in the volume
                let appName = try FileManager.default.contentsOfDirectory(atPath: volume)
                    .first(where: { $0.hasSuffix(".app") })

                guard let appName else {
                    await MainActor.run { state = .failed(message: "No .app found in DMG") }
                    return
                }

                let sourceApp = "\(volume)/\(appName)"
                let destApp = "/Applications/Clipy.app"

                // Atomic replace: replaceItemAt keeps a backup of the old app
                // and swaps atomically so the user is never left without an app
                let destURL = URL(fileURLWithPath: destApp)
                let sourceURL = URL(fileURLWithPath: sourceApp)
                if FileManager.default.fileExists(atPath: destApp) {
                    _ = try FileManager.default.replaceItemAt(destURL, withItemAt: sourceURL, backupItemName: nil, options: .usingNewMetadataOnly)
                } else {
                    try FileManager.default.copyItem(at: sourceURL, to: destURL)
                }

                // Unmount DMG
                let detachProcess = Process()
                detachProcess.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                detachProcess.arguments = ["detach", volume, "-quiet"]
                try? detachProcess.run()
                detachProcess.waitUntilExit()

                // Clean up
                try? FileManager.default.removeItem(at: dmgPath)

                // Relaunch
                await MainActor.run {
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    task.arguments = [destApp]
                    try? task.run()

                    // Quit current instance after short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NSApplication.shared.terminate(nil)
                    }
                }
            } catch {
                await MainActor.run { state = .failed(message: "Install failed: \(error.localizedDescription)") }
            }
        }
    }
}

// MARK: - Legacy Panel Wrapper (only used for Global Hotkeys — KeyHolder RecordView requires AppKit)
struct LegacyPanelView: NSViewControllerRepresentable {
    let nibName: String

    func makeNSViewController(context: Context) -> NSViewController {
        return CPYShortcutsPreferenceViewController(nibName: nibName, bundle: nil)
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}
}

// MARK: - Shortcuts Preferences

struct ShortcutsPreferencesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Global Hotkeys — legacy XIB (has its own internal margins)
                VStack(alignment: .leading, spacing: 6) {
                    Label("Global Hotkeys", systemImage: "globe")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 44)

                    LegacyPanelView(nibName: "CPYShortcutsPreferenceViewController")
                        .frame(maxWidth: .infinity)
                        .frame(height: 275)
                }

                Divider()
                    .padding(.horizontal, 44)

                // Panel Shortcuts — native SwiftUI
                VStack(alignment: .leading, spacing: 10) {
                    Label("Search Panel Shortcuts", systemImage: "keyboard")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    PanelShortcutsList()
                }
                .padding(.horizontal, 44)
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
        ShortcutRow(name: "OCR (image clips)", shortcut: service.ocr, onRecord: { service.save($0) })
        ShortcutRow(name: "Share (image clips)", shortcut: service.share, onRecord: { service.save($0) })

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
        #if DEBUG
        window.title = "Clipy Dev Settings"
        #else
        window.title = "Clipy Settings"
        #endif
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
