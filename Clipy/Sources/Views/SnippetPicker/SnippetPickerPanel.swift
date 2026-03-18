// swiftlint:disable file_length
//
//  SnippetPickerPanel.swift
//
//  Clipy
//
//  Modern snippet picker panel — Spotlight-style UI for browsing and pasting snippets.
//  Folders are collapsed by default; navigate with arrow keys, expand to see snippets.
//

import SwiftUI
import RealmSwift
import LocalAuthentication
import TipKit

// MARK: - Data Models

struct PickerFolder: Identifiable {
    let id: String
    let title: String
    let isVault: Bool
    let snippets: [PickerSnippet]
}

struct PickerSnippet: Identifiable, Hashable {
    let id: String
    let title: String
    let content: String
    let folderTitle: String
    let hasVariables: Bool

    init(id: String, title: String, content: String, folderTitle: String) {
        self.id = id
        self.title = title
        self.content = content
        self.folderTitle = folderTitle
        self.hasVariables = content.contains("%") && SnippetVariableProcessor.availableVariables.contains { content.contains($0.name) }
    }

    var preview: String {
        let line = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(2)
            .joined(separator: " \u{2022} ")
        return String(line.prefix(120))
    }
}

// MARK: - ViewModel

@MainActor
class SnippetPickerViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var folders = [PickerFolder]()
    @Published var expandedFolderIDs = Set<String>()
    @Published var selectedID: String = ""

    private var allFolders = [PickerFolder]()

    // Two-digit quick select: type "1" then "4" quickly to select snippet 14
    var digitBuffer = ""
    var digitTimer: DispatchWorkItem?

    func handleDigitPress(_ digit: Character) {
        digitTimer?.cancel()
        digitBuffer.append(digit)

        if digitBuffer.count >= 2 {
            if let num = Int(digitBuffer) {
                pasteQuickIndex(num - 1)
            }
            digitBuffer = ""
            return
        }

        let timer = DispatchWorkItem { [weak self] in
            guard let self, !self.digitBuffer.isEmpty else { return }
            if let num = Int(self.digitBuffer) {
                self.pasteQuickIndex(num - 1)
            }
            self.digitBuffer = ""
        }
        digitTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: timer)
    }

    // Flat list of visible row IDs for keyboard navigation
    var visibleIDs: [String] {
        var ids = [String]()
        for folder in folders {
            ids.append(folder.id)
            if expandedFolderIDs.contains(folder.id) {
                for snippet in folder.snippets {
                    ids.append(snippet.id)
                }
            }
        }
        return ids
    }

    func load(filterFolderID: String? = nil) {
        guard let realm = Realm.safeInstance() else { return }
        let results = realm.objects(CPYFolder.self)
            .sorted(byKeyPath: #keyPath(CPYFolder.index), ascending: true)

        allFolders = results.compactMap { folder -> PickerFolder? in
            guard folder.enable else { return nil }
            if let filterID = filterFolderID, folder.identifier != filterID { return nil }

            let snippets = folder.snippets
                .sorted(byKeyPath: #keyPath(CPYSnippet.index), ascending: true)
                .filter { $0.enable }
                .map { snippet in
                    PickerSnippet(
                        id: snippet.identifier,
                        title: snippet.title,
                        content: snippet.content,
                        folderTitle: folder.title
                    )
                }
            guard !snippets.isEmpty else { return nil }
            return PickerFolder(id: folder.identifier, title: folder.title, isVault: folder.isVault, snippets: Array(snippets))
        }

        // If opened for a specific folder, auto-expand it
        if let filterID = filterFolderID {
            expandedFolderIDs = [filterID]
        }

        applyFilter()
    }

    func applyFilter() {
        if searchText.isEmpty {
            folders = allFolders
        } else {
            let terms = searchText.lowercased().split(separator: " ").map(String.init)
            folders = allFolders.compactMap { folder in
                // Don't search inside locked vault folders
                if folder.isVault && !VaultAuthService.shared.isUnlocked(folder.id) { return nil }
                let matching = folder.snippets.filter { snippet in
                    let haystack = (snippet.title + " " + snippet.content + " " + snippet.folderTitle).lowercased()
                    return terms.allSatisfy { haystack.contains($0) }
                }
                guard !matching.isEmpty else { return nil }
                return PickerFolder(id: folder.id, title: folder.title, isVault: folder.isVault, snippets: matching)
            }
            // When searching, auto-expand all folders so results are visible
            expandedFolderIDs = Set(folders.map { $0.id })
        }

        // Select first visible item
        if let first = visibleIDs.first {
            selectedID = first
        }
    }

    func moveSelection(by offset: Int) {
        let ids = visibleIDs
        guard !ids.isEmpty else { return }
        guard let currentPos = ids.firstIndex(of: selectedID) else {
            selectedID = ids.first ?? ""
            return
        }
        let newPos = max(0, min(ids.count - 1, currentPos + offset))
        selectedID = ids[newPos]
    }

    func toggleExpand(_ folderID: String) {
        if expandedFolderIDs.contains(folderID) {
            expandedFolderIDs.remove(folderID)
            // Lock vault folders when collapsed
            if let folder = folders.first(where: { $0.id == folderID }), folder.isVault {
                VaultAuthService.shared.lock(folderID)
            }
        } else {
            expandedFolderIDs.insert(folderID)
        }
    }

    private func expandVaultFolder(_ folder: PickerFolder, thenSelectFirst: Bool = false) {
        VaultAuthService.shared.authenticate(folderID: folder.id, reason: "Unlock \"\(folder.title)\" vault") { [weak self] success in
            DispatchQueue.main.async {
                if success, let self {
                    self.expandedFolderIDs.insert(folder.id)
                    if thenSelectFirst, let first = folder.snippets.first {
                        self.selectedID = first.id
                    }
                }
                // Force app activation then panel focus after Touch ID
                NSApp.activate(ignoringOtherApps: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    SnippetPickerWindowController.shared.window?.orderFrontRegardless()
                    SnippetPickerWindowController.shared.window?.makeKey()
                }
            }
        }
    }

    func handleReturn() {
        // If a folder is selected, toggle it
        if let folder = folders.first(where: { $0.id == selectedID }) {
            // Vault folder needs auth to expand
            if folder.isVault && !expandedFolderIDs.contains(selectedID) {
                expandVaultFolder(folder, thenSelectFirst: true)
                return
            }
            toggleExpand(selectedID)
            // Move selection to first snippet if expanding
            if expandedFolderIDs.contains(selectedID),
               let first = folder.snippets.first {
                selectedID = first.id
            }
            return
        }
        // If a snippet is selected, paste it
        pasteSnippet(withID: selectedID)
    }

    func handleRightArrow() {
        // If on a folder, expand it
        if let folder = folders.first(where: { $0.id == selectedID }) {
            if !expandedFolderIDs.contains(selectedID) {
                // Vault folder needs auth
                if folder.isVault {
                    expandVaultFolder(folder, thenSelectFirst: true)
                    return
                }
                expandedFolderIDs.insert(selectedID)
            }
            // Move into the folder
            if let first = folder.snippets.first {
                selectedID = first.id
            }
        }
    }

    func handleLeftArrow() {
        // If on a snippet, collapse its parent and select the folder
        for folder in folders {
            if folder.snippets.contains(where: { $0.id == selectedID }) {
                toggleExpand(folder.id) // This also locks vault folders
                selectedID = folder.id
                return
            }
        }
        // If on an expanded folder, collapse it
        if expandedFolderIDs.contains(selectedID) {
            toggleExpand(selectedID)
        }
    }

    func pasteSnippet(withID id: String) {
        for folder in allFolders {
            if let snippet = folder.snippets.first(where: { $0.id == id }) {
                let processed = SnippetVariableProcessor.process(snippet.content)
                AppEnvironment.current.pasteService.copyToPasteboard(with: processed)
                SnippetPickerWindowController.shared.dismissAndPaste()
                return
            }
        }
    }

    func pasteQuickIndex(_ index: Int) {
        // Quick-paste only counts visible snippets (not folders)
        let snippetIDs = visibleIDs.filter { id in
            folders.contains { $0.snippets.contains { $0.id == id } }
        }
        guard index < snippetIDs.count else { return }
        selectedID = snippetIDs[index]
        pasteSnippet(withID: snippetIDs[index])
    }

    var totalSnippetCount: Int {
        folders.reduce(0) { $0 + $1.snippets.count }
    }

    func reset(filterFolderID: String? = nil) {
        searchText = ""
        expandedFolderIDs = []
        selectedID = ""
        VaultAuthService.shared.lockAll()
        load(filterFolderID: filterFolderID)
    }
}

// MARK: - Panel View

struct SnippetPickerPanelView: View {
    @StateObject private var viewModel = SnippetPickerViewModel()
    @FocusState private var isSearchFocused: Bool
    let filterFolderID: String?
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().opacity(0.4)
            snippetList
            Divider().opacity(0.4)
            footerBar
        }
        .frame(width: 440, height: 460)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
        .onAppear {
            viewModel.reset(filterFolderID: filterFolderID)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFocused = true
            }
        }
        .onKeyPress(.upArrow, phases: [.down, .repeat]) { _ in viewModel.moveSelection(by: -1); return .handled }
        .onKeyPress(.downArrow, phases: [.down, .repeat]) { _ in viewModel.moveSelection(by: 1); return .handled }
        .onKeyPress(.rightArrow, phases: .down) { _ in viewModel.handleRightArrow(); return .handled }
        .onKeyPress(.leftArrow, phases: .down) { _ in viewModel.handleLeftArrow(); return .handled }
        .onKeyPress(.escape) { onDismiss(); return .handled }
        .onKeyPress(.return) { viewModel.handleReturn(); return .handled }
        .onKeyPress(characters: .init(charactersIn: "1234567890"), phases: .down) { press in
            if press.modifiers.isEmpty, let digit = press.characters.first {
                viewModel.handleDigitPress(digit)
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.snippet")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(.secondary)

            TextField("Search snippets\u{2026}", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .light))
                .focused($isSearchFocused)
                .onChange(of: viewModel.searchText) { _, _ in
                    viewModel.applyFilter()
                }

            if !viewModel.searchText.isEmpty {
                Button { viewModel.searchText = ""; viewModel.applyFilter() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .popoverTip(SnippetNavigationTip(), arrowEdge: .bottom)
    }

    // MARK: - List

    private var snippetList: some View {
        Group {
            if viewModel.folders.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: viewModel.searchText.isEmpty ? "text.snippet" : "magnifyingglass")
                        .font(.system(size: 28, weight: .ultraLight))
                        .foregroundStyle(.quaternary)
                    Text(viewModel.searchText.isEmpty ? "No snippets" : "No matches")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            let rankMap = snippetRankMap()
                            ForEach(viewModel.folders) { folder in
                                folderRow(folder)
                                    .id(folder.id)

                                if viewModel.expandedFolderIDs.contains(folder.id) {
                                    ForEach(folder.snippets) { snippet in
                                        snippetRow(snippet, rank: rankMap[snippet.id] ?? 0)
                                            .id(snippet.id)
                                    }
                                }
                            }
                        }
                        .padding(6)
                    }
                    .onChange(of: viewModel.selectedID) { _, newValue in
                        withAnimation(.easeOut(duration: 0.08)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Folder Row

    private func folderRow(_ folder: PickerFolder) -> some View {
        let isSelected = viewModel.selectedID == folder.id
        let isExpanded = viewModel.expandedFolderIDs.contains(folder.id)

        return HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.6)) : AnyShapeStyle(.tertiary))
                .rotationEffect(isExpanded ? .degrees(90) : .zero)
                .animation(.easeOut(duration: 0.15), value: isExpanded)
                .frame(width: 14)

            Image(systemName: folder.isVault ? (isExpanded ? "lock.open.fill" : "lock.fill") : "folder.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? .white : folder.isVault ? (isExpanded ? SwiftUI.Color.green : SwiftUI.Color.orange) : SwiftUI.Color.accentColor)
                .frame(width: 26, height: 26)
                .background(
                    isSelected
                        ? AnyShapeStyle(.white.opacity(0.15))
                        : AnyShapeStyle(folder.isVault ? (isExpanded ? SwiftUI.Color.green.opacity(0.1) : SwiftUI.Color.orange.opacity(0.1)) : SwiftUI.Color.accentColor.opacity(0.1))
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(folder.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)

            Spacer()

            Text("\(folder.snippets.count)")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.6)) : AnyShapeStyle(.tertiary))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(isSelected ? AnyShapeStyle(.white.opacity(0.15)) : AnyShapeStyle(.quaternary.opacity(0.4)))
                .clipShape(Capsule())

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.4)) : AnyShapeStyle(.quaternary))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            isSelected
                ? AnyShapeStyle(SwiftUI.Color.accentColor.opacity(0.85))
                : AnyShapeStyle(SwiftUI.Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedID = folder.id
            if folder.isVault && !viewModel.expandedFolderIDs.contains(folder.id) {
                VaultAuthService.shared.authenticate(folderID: folder.id, reason: "Unlock \"\(folder.title)\" vault") { success in
                    DispatchQueue.main.async {
                        if success {
                            viewModel.expandedFolderIDs.insert(folder.id)
                        }
                        NSApp.activate(ignoringOtherApps: true)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            SnippetPickerWindowController.shared.window?.orderFrontRegardless()
                            SnippetPickerWindowController.shared.window?.makeKey()
                        }
                    }
                }
            } else {
                viewModel.toggleExpand(folder.id)
            }
        }
    }

    private func snippetRankMap() -> [String: Int] {
        var map = [String: Int]()
        var rank = 1
        for folder in viewModel.folders {
            if viewModel.expandedFolderIDs.contains(folder.id) {
                for snippet in folder.snippets {
                    map[snippet.id] = rank
                    rank += 1
                }
            }
        }
        return map
    }

    // MARK: - Snippet Row

    private func snippetRow(_ snippet: PickerSnippet, rank: Int) -> some View {
        let isSelected = viewModel.selectedID == snippet.id

        return HStack(spacing: 8) {
            // Rank number
            Text("\(rank)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary.opacity(0.5))
                .frame(width: 18)

            Image(systemName: snippet.hasVariables ? "function" : "doc.text.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : snippet.hasVariables ? AnyShapeStyle(.orange) : AnyShapeStyle(.blue))
                .frame(width: 22, height: 22)
                .background(
                    isSelected
                        ? AnyShapeStyle(.white.opacity(0.15))
                        : AnyShapeStyle(snippet.hasVariables ? SwiftUI.Color.orange.opacity(0.08) : SwiftUI.Color.blue.opacity(0.08))
                )
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(snippet.title.isEmpty ? "Untitled" : snippet.title)
                        .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)

                    if snippet.hasVariables {
                        Text("%VAR")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? .white.opacity(0.7) : .orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(isSelected ? .white.opacity(0.15) : SwiftUI.Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                if !snippet.preview.isEmpty {
                    Text(snippet.preview)
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.6)) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            isSelected
                ? AnyShapeStyle(SwiftUI.Color.accentColor.opacity(0.75))
                : AnyShapeStyle(SwiftUI.Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedID = snippet.id
        }
        .onTapGesture(count: 2) {
            viewModel.selectedID = snippet.id
            viewModel.pasteSnippet(withID: snippet.id)
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 14) {
            kbHint("\u{23CE}", "open/paste")
            kbHint("\u{2190}\u{2192}", "collapse/expand")
            kbHint("\u{2191}\u{2193}", "navigate")
            kbHint("esc", "close")
            Spacer()
            Text("\(viewModel.totalSnippetCount) snippets")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
    }

    private func kbHint(_ key: String, _ label: String) -> some View {
        KeyboardHintView(key: key, label: label)
    }
}

// MARK: - Window Controller

class SnippetPickerWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SnippetPickerWindowController()

    private init() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 460),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false

        super.init(window: panel)
        panel.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func toggle(filterFolderID: String? = nil) {
        if window?.isVisible == true {
            dismiss()
        } else {
            show(filterFolderID: filterFolderID)
        }
    }

    func show(filterFolderID: String? = nil) {
        guard let panel = window else { return }

        let hostView = NSHostingView(rootView: SnippetPickerPanelView(
            filterFolderID: filterFolderID,
            onDismiss: { [weak self] in self?.dismiss() }
        ))
        hostView.frame = NSRect(x: 0, y: 0, width: 440, height: 460)
        panel.contentView = hostView
        // Ensure hosting view layer is transparent after being added to window
        DispatchQueue.main.async {
            hostView.wantsLayer = true
            hostView.layer?.backgroundColor = .clear
            hostView.layer?.isOpaque = false
        }
        panel.setContentSize(NSSize(width: 440, height: 460))

        if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            let originX = screenFrame.midX - 220
            let originY = screenFrame.midY - 230 + screenFrame.height * 0.06
            panel.setFrameOrigin(NSPoint(x: originX, y: originY))
        }

        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func dismiss() {
        window?.orderOut(nil)
        window?.contentView = nil
    }

    func dismissAndPaste() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AppEnvironment.current.pasteService.paste()
        }
    }

    func windowWillClose(_ notification: Notification) {
        window?.contentView = nil
    }
}
