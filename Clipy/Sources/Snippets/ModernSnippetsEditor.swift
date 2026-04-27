// swiftlint:disable file_length
//
//  ModernSnippetsEditor.swift
//
//  Clipy
//
//  Modern SwiftUI snippets editor — liquid glass design matching the search panel.
//

import SwiftUI
import RealmSwift
import AEXML
import UniformTypeIdentifiers
import LocalAuthentication
import TipKit

// MARK: - Snippets ViewModel
@MainActor
class SnippetsEditorViewModel: ObservableObject {
    @Published var folders = [FolderItem]()
    @Published var selectedFolderID: String?
    @Published var selectedSnippetID: String?
    @Published var editingTitle = ""
    @Published var editingContent = ""
    @Published var editingSnippetType = CPYSnippet.SnippetType.plainText.rawValue
    @Published var editingScriptShell = CPYSnippet.defaultShell
    @Published var editingScriptTimeout = CPYSnippet.defaultTimeout
    @Published var editingIsEphemeral = true
    @Published var sidebarFilter = ""
    @Published var hasUnsavedChanges = false
    @Published var expandedFolderIDs = Set<String>()
    @Published var needsRefocus = false
    @Published var scriptTestOutput: String?
    @Published var isRunningTest = false
    @Published var showingTemplates = false

    struct FolderItem: Identifiable, Hashable {
        let id: String
        var title: String
        var enabled: Bool
        var isVault: Bool
        var snippets: [SnippetItem]
    }

    struct SnippetItem: Identifiable, Hashable {
        let id: String
        var title: String
        var content: String
        var enabled: Bool
        var snippetType: Int
        var scriptShell: String
        var scriptTimeout: Int
        var isEphemeral: Bool

        var isScript: Bool { snippetType == CPYSnippet.SnippetType.script.rawValue }
    }

    func load() {
        guard let realm = Realm.safeInstance() else { return }
        let results = realm.objects(CPYFolder.self)
            .sorted(byKeyPath: #keyPath(CPYFolder.index), ascending: true)

        folders = results.map { folder in
            let snippets = folder.snippets
                .sorted(byKeyPath: #keyPath(CPYSnippet.index), ascending: true)
                .map { snippet in
                    SnippetItem(id: snippet.identifier, title: snippet.title, content: snippet.content, enabled: snippet.enable, snippetType: snippet.snippetType, scriptShell: snippet.scriptShell, scriptTimeout: snippet.scriptTimeout, isEphemeral: snippet.isEphemeral)
                }
            return FolderItem(id: folder.identifier, title: folder.title, enabled: folder.enable, isVault: folder.isVault, snippets: Array(snippets))
        }

        // Initialize expanded state for new folders (non-vault start expanded)
        for folder in folders where !expandedFolderIDs.contains(folder.id) && !folder.isVault {
            expandedFolderIDs.insert(folder.id)
        }

        if selectedFolderID == nil {
            selectedFolderID = folders.first?.id
        }

        if let snippetID = selectedSnippetID {
            if let folder = folders.first(where: { $0.snippets.contains(where: { $0.id == snippetID }) }),
               let snippet = folder.snippets.first(where: { $0.id == snippetID }) {
                editingTitle = snippet.title
                editingContent = snippet.content
                editingSnippetType = snippet.snippetType
                editingScriptShell = snippet.scriptShell
                editingScriptTimeout = snippet.scriptTimeout
                editingIsEphemeral = snippet.isEphemeral
                hasUnsavedChanges = false
            }
        }
    }

    func selectSnippet(_ snippet: SnippetItem) {
        if hasUnsavedChanges { saveCurrentSnippet() }
        selectedSnippetID = snippet.id
        editingTitle = snippet.title
        editingContent = snippet.content
        editingSnippetType = snippet.snippetType
        editingScriptShell = snippet.scriptShell
        editingScriptTimeout = snippet.scriptTimeout
        editingIsEphemeral = snippet.isEphemeral
        scriptTestOutput = nil
        hasUnsavedChanges = false
    }

    func saveCurrentSnippet() {
        guard let snippetID = selectedSnippetID else { return }
        guard let realm = Realm.safeInstance() else { return }
        guard let snippet = realm.object(ofType: CPYSnippet.self, forPrimaryKey: snippetID) else { return }
        realm.transaction {
            snippet.title = editingTitle
            snippet.content = editingContent
            snippet.snippetType = editingSnippetType
            snippet.scriptShell = editingScriptShell
            snippet.scriptTimeout = editingScriptTimeout
            snippet.isEphemeral = editingIsEphemeral
        }
        hasUnsavedChanges = false
        load()
    }

    func testRunScript() {
        guard editingSnippetType == CPYSnippet.SnippetType.script.rawValue else { return }
        isRunningTest = true
        scriptTestOutput = nil
        ScriptExecutionService.execute(
            script: editingContent,
            shell: editingScriptShell,
            timeout: TimeInterval(editingScriptTimeout)
        ) { [weak self] result in
            self?.isRunningTest = false
            if result.timedOut {
                self?.scriptTestOutput = "[Timed out after \(self?.editingScriptTimeout ?? 10)s]"
            } else if result.exitCode != 0 {
                self?.scriptTestOutput = "[Exit \(result.exitCode)] \(result.error ?? "")\n\(result.output)"
            } else {
                self?.scriptTestOutput = result.output.isEmpty ? "[No output]" : result.output
            }
        }
    }

    /// Template pending parameter configuration (shown in config sheet).
    @Published var pendingTemplate: SnippetTemplate?
    @Published var pendingTemplateValues: [String: String] = [:]

    func installTemplate(_ template: SnippetTemplate, values: [String: String] = [:]) {
        let folderID: String
        if let selected = selectedFolderID {
            folderID = selected
        } else {
            let newFolder = CPYFolder.create()
            newFolder.title = "Script Snippets"
            newFolder.merge()
            load()
            folderID = newFolder.identifier
            selectedFolderID = folderID
        }

        guard let realm = Realm.safeInstance() else { return }
        guard let folder = realm.object(ofType: CPYFolder.self, forPrimaryKey: folderID) else { return }
        let snippet = folder.createSnippet()
        snippet.title = template.name
        snippet.content = template.resolvedContent(with: values)
        snippet.snippetType = CPYSnippet.SnippetType.script.rawValue
        snippet.scriptShell = template.shell
        snippet.scriptTimeout = template.timeout
        folder.mergeSnippet(snippet)
        load()

        // Select the new snippet
        if let folderItem = folders.first(where: { $0.id == folderID }),
           let newSnippet = folderItem.snippets.last {
            selectSnippet(newSnippet)
            expandedFolderIDs.insert(folderID)
        }
        showingTemplates = false
    }

    func addFolder() {
        let folder = CPYFolder.create()
        folder.merge()
        load()
        selectedFolderID = folder.identifier
    }

    func removeFolder(_ folderID: String) {
        guard let realm = Realm.safeInstance() else { return }
        guard let folder = realm.object(ofType: CPYFolder.self, forPrimaryKey: folderID) else { return }
        folder.remove()
        if selectedFolderID == folderID {
            selectedFolderID = nil
            selectedSnippetID = nil
        }
        load()
    }

    func addSnippet(to folderID: String) {
        guard let realm = Realm.safeInstance() else { return }
        guard let folder = realm.object(ofType: CPYFolder.self, forPrimaryKey: folderID) else { return }
        let snippet = folder.createSnippet()
        folder.mergeSnippet(snippet)
        load()
        if let folderItem = folders.first(where: { $0.id == folderID }),
           let newSnippet = folderItem.snippets.last {
            selectSnippet(newSnippet)
        }
    }

    func removeSnippet(_ snippetID: String) {
        guard let realm = Realm.safeInstance() else { return }
        guard let snippet = realm.object(ofType: CPYSnippet.self, forPrimaryKey: snippetID) else { return }
        snippet.remove()
        if selectedSnippetID == snippetID {
            selectedSnippetID = nil
            editingTitle = ""
            editingContent = ""
            editingSnippetType = CPYSnippet.SnippetType.plainText.rawValue
            editingScriptShell = CPYSnippet.defaultShell
            editingScriptTimeout = CPYSnippet.defaultTimeout
            scriptTestOutput = nil
            hasUnsavedChanges = false
        }
        load()
    }

    func toggleFolder(_ folderID: String) {
        guard let realm = Realm.safeInstance() else { return }
        guard let folder = realm.object(ofType: CPYFolder.self, forPrimaryKey: folderID) else { return }
        realm.transaction { folder.enable = !folder.enable }
        load()
    }

    func toggleSnippet(_ snippetID: String) {
        guard let realm = Realm.safeInstance() else { return }
        guard let snippet = realm.object(ofType: CPYSnippet.self, forPrimaryKey: snippetID) else { return }
        realm.transaction { snippet.enable = !snippet.enable }
        load()
    }

    func toggleVault(_ folderID: String) {
        guard let realm = Realm.safeInstance() else { return }
        guard let folder = realm.object(ofType: CPYFolder.self, forPrimaryKey: folderID) else { return }
        realm.transaction { folder.isVault = !folder.isVault }
        if !folder.isVault {
            VaultAuthService.shared.lock(folderID)
        }
        load()
    }

    func renameFolder(_ folderID: String, to newTitle: String) {
        guard let realm = Realm.safeInstance() else { return }
        guard let folder = realm.object(ofType: CPYFolder.self, forPrimaryKey: folderID) else { return }
        realm.transaction { folder.title = newTitle }
        load()
    }

    var selectedFolder: FolderItem? {
        folders.first { $0.id == selectedFolderID }
    }

    var totalSnippetCount: Int {
        folders.reduce(0) { $0 + $1.snippets.count }
    }

    // MARK: - Arrow Key Navigation

    /// Flat list of all selectable items (folders and their snippets) for arrow key navigation
    private var flatItems: [(kind: String, id: String, folderID: String?)] {
        var items = [(kind: String, id: String, folderID: String?)]()
        for folder in filteredFolders {
            items.append(("folder", folder.id, nil))
            if expandedFolderIDs.contains(folder.id) {
                for snippet in folder.snippets {
                    items.append(("snippet", snippet.id, folder.id))
                }
            }
        }
        return items
    }

    func moveSelectionUp() {
        let items = flatItems
        guard !items.isEmpty else { return }

        // Find current position
        let currentIndex: Int?
        if let sid = selectedSnippetID {
            currentIndex = items.firstIndex(where: { $0.kind == "snippet" && $0.id == sid })
        } else if let fid = selectedFolderID {
            currentIndex = items.firstIndex(where: { $0.kind == "folder" && $0.id == fid })
        } else {
            currentIndex = nil
        }

        let targetIndex = (currentIndex ?? items.count) - 1
        guard targetIndex >= 0 else { return }
        selectItem(items[targetIndex])
    }

    func moveSelectionDown() {
        let items = flatItems
        guard !items.isEmpty else { return }

        let currentIndex: Int?
        if let sid = selectedSnippetID {
            currentIndex = items.firstIndex(where: { $0.kind == "snippet" && $0.id == sid })
        } else if let fid = selectedFolderID {
            currentIndex = items.firstIndex(where: { $0.kind == "folder" && $0.id == fid })
        } else {
            currentIndex = nil
        }

        let targetIndex = (currentIndex ?? -1) + 1
        guard targetIndex < items.count else { return }
        selectItem(items[targetIndex])
    }

    func expandSelected() {
        guard let fid = selectedFolderID, selectedSnippetID == nil else { return }
        if !expandedFolderIDs.contains(fid) {
            if let folder = folders.first(where: { $0.id == fid }), folder.isVault, !VaultAuthService.shared.isUnlocked(fid) {
                // Vault folder — authenticate first
                VaultAuthService.shared.authenticate(folderID: fid, reason: "Unlock \"\(folder.title)\" vault") { [weak self] success in
                    DispatchQueue.main.async {
                        if success {
                            withAnimation(.easeOut(duration: 0.15)) { _ = self?.expandedFolderIDs.insert(fid) }
                        }
                        // Force app activation and window focus after Touch ID
                        NSApp.activate(ignoringOtherApps: true)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            ModernSnippetsWindowController.shared.window?.makeKeyAndOrderFront(nil)
                            self?.needsRefocus = true
                        }
                    }
                }
                return
            }
            withAnimation(.easeOut(duration: 0.15)) { expandedFolderIDs.insert(fid) }
        } else {
            // Already expanded — move into first snippet
            if let folder = filteredFolders.first(where: { $0.id == fid }), let first = folder.snippets.first {
                selectSnippet(first)
            }
        }
    }

    func collapseSelected() {
        if let sid = selectedSnippetID {
            // On a snippet — jump back to its folder
            if let folder = folders.first(where: { $0.snippets.contains(where: { $0.id == sid }) }) {
                selectedFolderID = folder.id
                selectedSnippetID = nil
                editingTitle = ""
                editingContent = ""
                hasUnsavedChanges = false
            }
        } else if let fid = selectedFolderID, expandedFolderIDs.contains(fid) {
            withAnimation(.easeOut(duration: 0.15)) { expandedFolderIDs.remove(fid) }
        }
    }

    private func selectItem(_ item: (kind: String, id: String, folderID: String?)) {
        if item.kind == "folder" {
            if hasUnsavedChanges { saveCurrentSnippet() }
            selectedFolderID = item.id
            selectedSnippetID = nil
            editingTitle = ""
            editingContent = ""
            hasUnsavedChanges = false
        } else if let snippet = folders.flatMap({ $0.snippets }).first(where: { $0.id == item.id }) {
            selectedFolderID = item.folderID
            selectSnippet(snippet)
        }
    }

    var filteredFolders: [FolderItem] {
        guard !sidebarFilter.isEmpty else { return folders }
        let query = sidebarFilter.lowercased()
        return folders.compactMap { folder in
            let matchingSnippets = folder.snippets.filter {
                $0.title.lowercased().contains(query) || $0.content.lowercased().contains(query)
            }
            let folderMatches = folder.title.lowercased().contains(query)
            if folderMatches || !matchingSnippets.isEmpty {
                return FolderItem(
                    id: folder.id,
                    title: folder.title,
                    enabled: folder.enabled,
                    isVault: folder.isVault,
                    snippets: folderMatches ? folder.snippets : matchingSnippets
                )
            }
            return nil
        }
    }

}

// MARK: - Import / Export
extension SnippetsEditorViewModel {
    func exportSnippets() {
        let xmlDocument = AEXMLDocument()
        let rootElement = xmlDocument.addChild(name: Constants.Xml.rootElement)

        guard let realm = Realm.safeInstance() else { return }
        let realmFolders = realm.objects(CPYFolder.self)
            .sorted(byKeyPath: #keyPath(CPYFolder.index), ascending: true)

        realmFolders.forEach { folder in
            // Skip vault folders — protected content should not be exported
            if folder.isVault { return }
            let folderElement = rootElement.addChild(name: Constants.Xml.folderElement)
            folderElement.addChild(name: Constants.Xml.titleElement, value: folder.title)
            let snippetsElement = folderElement.addChild(name: Constants.Xml.snippetsElement)
            folder.snippets
                .sorted(byKeyPath: #keyPath(CPYSnippet.index), ascending: true)
                .forEach { snippet in
                    let snippetElement = snippetsElement.addChild(name: Constants.Xml.snippetElement)
                    snippetElement.addChild(name: Constants.Xml.titleElement, value: snippet.title)
                    snippetElement.addChild(name: Constants.Xml.contentElement, value: snippet.content)
                    if snippet.snippetType != CPYSnippet.SnippetType.plainText.rawValue {
                        snippetElement.addChild(name: "type", value: "\(snippet.snippetType)")
                        snippetElement.addChild(name: "shell", value: snippet.scriptShell)
                        snippetElement.addChild(name: "timeout", value: "\(snippet.scriptTimeout)")
                        snippetElement.addChild(name: "ephemeral", value: snippet.isEphemeral ? "true" : "false")
                    }
                }
        }

        let panel = NSSavePanel()
        panel.canSelectHiddenExtension = true
        panel.allowedContentTypes = [.xml]
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        panel.nameFieldStringValue = "snippets"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = xmlDocument.xml.data(using: .utf8) else { return }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            NSSound.beep()
        }
    }

    func importSnippets() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        panel.allowedContentTypes = [.xml]

        guard panel.runModal() == .OK, let url = panel.urls.first else { return }
        guard let data = try? Data(contentsOf: url) else { return }

        do {
            guard let realm = Realm.safeInstance() else { return }
            let lastFolder = realm.objects(CPYFolder.self)
                .sorted(byKeyPath: #keyPath(CPYFolder.index), ascending: true).last
            var folderIndex = (lastFolder?.index ?? -1) + 1

            var options = AEXMLOptions()
            options.parserSettings.shouldTrimWhitespace = false
            let xmlDocument = try AEXMLDocument(xml: data, options: options)

            realm.transaction {
                xmlDocument[Constants.Xml.rootElement].children.forEach { folderElement in
                    let folder = CPYFolder()
                    folder.title = folderElement[Constants.Xml.titleElement].value ?? "untitled folder"
                    folder.index = folderIndex
                    realm.add(folder)

                    var snippetIndex = 0
                    folderElement[Constants.Xml.snippetsElement][Constants.Xml.snippetElement]
                        .all?
                        .forEach { snippetElement in
                            let snippet = CPYSnippet()
                            snippet.title = snippetElement[Constants.Xml.titleElement].value ?? "untitled snippet"
                            snippet.content = snippetElement[Constants.Xml.contentElement].value ?? ""
                            snippet.snippetType = Int(snippetElement["type"].value ?? "0") ?? 0
                            snippet.scriptShell = snippetElement["shell"].value ?? CPYSnippet.defaultShell
                            snippet.scriptTimeout = Int(snippetElement["timeout"].value ?? "\(CPYSnippet.defaultTimeout)") ?? CPYSnippet.defaultTimeout
                            if let ephemeralValue = snippetElement["ephemeral"].value {
                                snippet.isEphemeral = (ephemeralValue.lowercased() == "true" || ephemeralValue == "1")
                            }
                            snippet.index = snippetIndex
                            folder.snippets.append(snippet)
                            snippetIndex += 1
                        }
                    folderIndex += 1
                }
            }
            load()
        } catch {
            NSSound.beep()
        }
    }
}

// MARK: - Main Editor View
// swiftlint:disable:next type_body_length
struct ModernSnippetsEditorView: View {
    @StateObject private var viewModel = SnippetsEditorViewModel()
    @FocusState private var sidebarFocused: Bool
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 260)
            Divider().opacity(0.4)
            editorPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 740, height: 520)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
        .overlay(DevBadgeOverlay())
        .onAppear { viewModel.load() }
        .onChange(of: viewModel.needsRefocus) { _, needs in
            if needs {
                viewModel.needsRefocus = false
                sidebarFocused = true
            }
        }
        .sheet(isPresented: $viewModel.showingTemplates) {
            SnippetTemplateGalleryView(viewModel: viewModel)
        }
    }

    // MARK: - Sidebar
    private var sidebar: some View {
        VStack(spacing: 0) {
            // Search/filter bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(.tertiary)
                TextField("Filter snippets\u{2026}", text: $viewModel.sidebarFilter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .light))
                if !viewModel.sidebarFilter.isEmpty {
                    Button { viewModel.sidebarFilter = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().opacity(0.4)

            // Folder list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(viewModel.filteredFolders) { folder in
                        SnippetFolderRow(
                            folder: folder,
                            isSelected: viewModel.selectedFolderID == folder.id,
                            selectedSnippetID: viewModel.selectedSnippetID,
                            onSelectFolder: { viewModel.selectedFolderID = folder.id },
                            onSelectSnippet: { viewModel.selectSnippet($0) },
                            onAddSnippet: { viewModel.addSnippet(to: folder.id) },
                            onDeleteFolder: { viewModel.removeFolder(folder.id) },
                            onDeleteSnippet: { viewModel.removeSnippet($0.id) },
                            onToggleFolder: { viewModel.toggleFolder(folder.id) },
                            onToggleSnippet: { viewModel.toggleSnippet($0.id) },
                            onRenameFolder: { viewModel.renameFolder(folder.id, to: $0) },
                            onToggleVault: { viewModel.toggleVault(folder.id) },
                            isExpanded: Binding(
                                get: { viewModel.expandedFolderIDs.contains(folder.id) },
                                set: { newValue in
                                    if newValue { viewModel.expandedFolderIDs.insert(folder.id) }
                                    else { viewModel.expandedFolderIDs.remove(folder.id) }
                                }
                            )
                        )
                    }
                }
                .padding(6)
            }

            Divider().opacity(0.4)

            // Footer toolbar
            sidebarFooter
        }
        .background(.black.opacity(0.03))
        .focusable()
        .focusEffectDisabled()
        .focused($sidebarFocused)
        .onAppear { sidebarFocused = true }
        .onKeyPress(.upArrow, phases: [.down, .repeat]) { _ in viewModel.moveSelectionUp(); return .handled }
        .onKeyPress(.downArrow, phases: [.down, .repeat]) { _ in viewModel.moveSelectionDown(); return .handled }
        .onKeyPress(.rightArrow, phases: .down) { _ in viewModel.expandSelected(); return .handled }
        .onKeyPress(.leftArrow, phases: .down) { _ in viewModel.collapseSelected(); return .handled }
    }

    private var sidebarFooter: some View {
        HStack(spacing: 6) {
            // Add folder
            SnippetToolbarButton(icon: "folder.badge.plus", help: "Add Folder") {
                viewModel.addFolder()
            }

            // Add snippet to current folder
            if viewModel.selectedFolderID != nil {
                SnippetToolbarButton(icon: "doc.badge.plus", help: "Add Snippet") {
                    if let folderID = viewModel.selectedFolderID {
                        viewModel.addSnippet(to: folderID)
                    }
                }
            }

            Spacer()

            Text("\(viewModel.totalSnippetCount) snippets")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)

            Spacer()

            SnippetToolbarButton(icon: "puzzlepiece.extension", help: "Templates") {
                viewModel.showingTemplates = true
            }

            SnippetToolbarButton(icon: "square.and.arrow.down", help: "Import") {
                viewModel.importSnippets()
            }
            SnippetToolbarButton(icon: "square.and.arrow.up", help: "Export") {
                viewModel.exportSnippets()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    // MARK: - Editor Pane
    private var editorPane: some View {
        Group {
            if let snippetID = viewModel.selectedSnippetID,
               let folder = viewModel.folders.first(where: { $0.snippets.contains(where: { $0.id == snippetID }) }),
               let snippet = folder.snippets.first(where: { $0.id == snippetID }) {
                VStack(spacing: 0) {
                    editorHeader(snippet: snippet, folder: folder)
                    Divider().opacity(0.3)
                    editorBody
                    Divider().opacity(0.3)
                    variablesBar
                    Divider().opacity(0.3)
                    editorFooter
                }
            } else {
                emptyEditor
            }
        }
        .background(.black.opacity(0.02))
    }

    private func editorHeader(snippet: SnippetsEditorViewModel.SnippetItem, folder: SnippetsEditorViewModel.FolderItem) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.editingSnippetType == CPYSnippet.SnippetType.script.rawValue ? "terminal.fill" : "doc.text.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(viewModel.editingSnippetType == CPYSnippet.SnippetType.script.rawValue ? .green : .blue)
                    .frame(width: 26, height: 26)
                    .background((viewModel.editingSnippetType == CPYSnippet.SnippetType.script.rawValue ? SwiftUI.Color.green : SwiftUI.Color.blue).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                TextField("Snippet title", text: $viewModel.editingTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .onChange(of: viewModel.editingTitle) { _, _ in
                        viewModel.hasUnsavedChanges = true
                    }

                Spacer()

                // Type toggle
                Picker("", selection: $viewModel.editingSnippetType) {
                    Text("Text").tag(0)
                    Text("Script").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                .onChange(of: viewModel.editingSnippetType) { _, _ in
                    viewModel.hasUnsavedChanges = true
                }

                // Folder breadcrumb
                HStack(spacing: 3) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 8))
                    Text(folder.title)
                        .font(.system(size: 9, weight: .medium))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .foregroundStyle(.secondary)

                // Enabled/disabled badge
                Circle()
                    .fill(snippet.enabled ? SwiftUI.Color.green : SwiftUI.Color.gray)
                    .frame(width: 7, height: 7)
                    .help(snippet.enabled ? "Enabled" : "Disabled")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Script settings row (only visible in script mode)
            if viewModel.editingSnippetType == CPYSnippet.SnippetType.script.rawValue {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                        Picker("Shell", selection: $viewModel.editingScriptShell) {
                            Text("/bin/bash").tag("/bin/bash")
                            Text("/bin/zsh").tag("/bin/zsh")
                            Text("/bin/sh").tag("/bin/sh")
                            Text("/usr/bin/env python3").tag("/usr/bin/env python3")
                        }
                        .labelsHidden()
                        .frame(width: 140)
                        .onChange(of: viewModel.editingScriptShell) { _, _ in
                            viewModel.hasUnsavedChanges = true
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                        Picker("Timeout", selection: $viewModel.editingScriptTimeout) {
                            Text("5s").tag(5)
                            Text("10s").tag(10)
                            Text("30s").tag(30)
                            Text("60s").tag(60)
                        }
                        .labelsHidden()
                        .frame(width: 70)
                        .onChange(of: viewModel.editingScriptTimeout) { _, _ in
                            viewModel.hasUnsavedChanges = true
                        }
                    }

                    // Ephemeral toggle — output not saved to history
                    Toggle(isOn: $viewModel.editingIsEphemeral) {
                        HStack(spacing: 3) {
                            Image(systemName: viewModel.editingIsEphemeral ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 9, weight: .medium))
                            Text("Ephemeral")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .help(viewModel.editingIsEphemeral ? "Output will NOT be saved to clipboard history (secure)" : "Output WILL be saved to clipboard history")
                    .onChange(of: viewModel.editingIsEphemeral) { _, _ in
                        viewModel.hasUnsavedChanges = true
                    }

                    Spacer()

                    Button {
                        viewModel.testRunScript()
                    } label: {
                        HStack(spacing: 4) {
                            if viewModel.isRunningTest {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9))
                            }
                            Text("Test Run")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.12))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isRunningTest)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.15), value: viewModel.editingSnippetType)
    }

    private var editorBody: some View {
        VStack(spacing: 0) {
            TextEditor(text: $viewModel.editingContent)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .onChange(of: viewModel.editingContent) { _, _ in
                    viewModel.hasUnsavedChanges = true
                }

            // Script test output panel
            if viewModel.editingSnippetType == CPYSnippet.SnippetType.script.rawValue, let output = viewModel.scriptTestOutput {
                Divider().opacity(0.3)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "text.terminal")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Test Output")
                            .font(.system(size: 10, weight: .semibold))
                        Spacer()
                        Button {
                            viewModel.scriptTestOutput = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(.secondary)

                    ScrollView {
                        Text(output)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(output.hasPrefix("[") ? .orange : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 120)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.04))
            }
        }
    }

    private var variablesBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                if viewModel.editingSnippetType == CPYSnippet.SnippetType.script.rawValue {
                    // Script mode: show environment variable hints
                    Image(systemName: "terminal")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.green.opacity(0.6))
                        .padding(.trailing, 2)

                    ForEach(ScriptExecutionService.availableEnvVars, id: \.name) { envVar in
                        Button {
                            viewModel.editingContent += envVar.name
                            viewModel.hasUnsavedChanges = true
                        } label: {
                            Text(envVar.name)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.green.opacity(0.06))
                                .foregroundStyle(.green.opacity(0.8))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(.green.opacity(0.1), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(envVar.desc)
                    }
                } else {
                    // Plain text mode: show variable placeholders
                    Image(systemName: "percent")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 2)

                    ForEach(SnippetVariableProcessor.availableVariables, id: \.name) { variable in
                        Button {
                            viewModel.editingContent += variable.name
                            viewModel.hasUnsavedChanges = true
                        } label: {
                            Text(variable.name)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.white.opacity(0.06))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(variable.desc)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
        }
    }

    private var editorFooter: some View {
        HStack(spacing: 12) {
            snippetKBHint("\u{2318}S", "save")
            snippetKBHint("\u{2318}N", "new")

            Spacer()

            if viewModel.hasUnsavedChanges {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 5, height: 5)
                    Text("Unsaved")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange)
                }
                .transition(.opacity)
            }

            Button {
                viewModel.saveCurrentSnippet()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                    Text("Save")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(viewModel.hasUnsavedChanges ? SwiftUI.Color.accentColor : .white.opacity(0.06))
                .foregroundStyle(viewModel.hasUnsavedChanges ? .white : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var emptyEditor: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(.quaternary)
            Text("Select a snippet to edit")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
            if viewModel.selectedFolderID != nil {
                Button {
                    if let folderID = viewModel.selectedFolderID {
                        viewModel.addSnippet(to: folderID)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("New Snippet")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(SwiftUI.Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func snippetKBHint(_ key: String, _ label: String) -> some View {
        KeyboardHintView(key: key, label: label)
    }
}

// MARK: - Folder Row
struct SnippetFolderRow: View {
    let folder: SnippetsEditorViewModel.FolderItem
    let isSelected: Bool
    let selectedSnippetID: String?
    let onSelectFolder: () -> Void
    let onSelectSnippet: (SnippetsEditorViewModel.SnippetItem) -> Void
    let onAddSnippet: () -> Void
    let onDeleteFolder: () -> Void
    let onDeleteSnippet: (SnippetsEditorViewModel.SnippetItem) -> Void
    let onToggleFolder: () -> Void
    let onToggleSnippet: (SnippetsEditorViewModel.SnippetItem) -> Void
    let onRenameFolder: (String) -> Void
    let onToggleVault: () -> Void

    @Binding var isExpanded: Bool
    @State private var isEditing = false
    @State private var editedTitle = ""
    @State private var isHovered = false
    @State private var isVaultUnlocked = false

    var body: some View {
        VStack(spacing: 1) {
            // Folder header
            HStack(spacing: 6) {
                Button {
                    if folder.isVault && !isVaultUnlocked && !isExpanded {
                        VaultAuthService.shared.authenticate(folderID: folder.id, reason: "Unlock \"\(folder.title)\" vault") { success in
                            DispatchQueue.main.async {
                                if success {
                                    isVaultUnlocked = true
                                    withAnimation(.easeOut(duration: 0.15)) { isExpanded = true }
                                }
                                NSApp.activate(ignoringOtherApps: true)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    ModernSnippetsWindowController.shared.window?.makeKeyAndOrderFront(nil)
                                }
                            }
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.15)) {
                            isExpanded.toggle()
                            if !isExpanded && folder.isVault {
                                isVaultUnlocked = false
                                VaultAuthService.shared.lock(folder.id)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(isExpanded ? .degrees(90) : .zero)
                        .frame(width: 14)
                }
                .buttonStyle(.plain)

                Image(systemName: folder.isVault ? (isVaultUnlocked ? "lock.open.fill" : "lock.fill") : folder.enabled ? "folder.fill" : "folder")
                    .font(.system(size: 12))
                    .foregroundStyle(folder.isVault ? (isVaultUnlocked ? SwiftUI.Color.green : SwiftUI.Color.orange) : folder.enabled ? SwiftUI.Color.accentColor : .secondary)

                if isEditing {
                    TextField("", text: $editedTitle, onCommit: {
                        onRenameFolder(editedTitle)
                        isEditing = false
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                } else {
                    Text(folder.title)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(folder.enabled ? .primary : .secondary)
                        .lineLimit(1)
                        .onTapGesture(count: 2) {
                            editedTitle = folder.title
                            isEditing = true
                        }
                }

                Spacer()

                // Hover: add snippet button
                if isHovered {
                    Button { onAddSnippet() } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }

                Text("\(folder.snippets.count)")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.7)) : AnyShapeStyle(.tertiary))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(isSelected ? AnyShapeStyle(.white.opacity(0.2)) : AnyShapeStyle(.quaternary.opacity(0.5)))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? AnyShapeStyle(SwiftUI.Color.accentColor.opacity(0.85))
                    : isHovered
                        ? AnyShapeStyle(.white.opacity(0.05))
                        : AnyShapeStyle(SwiftUI.Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { onSelectFolder() }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
            }
            .contextMenu {
                Button("Add Snippet") { onAddSnippet() }
                Button(folder.enabled ? "Disable" : "Enable") { onToggleFolder() }
                Divider()
                Button(folder.isVault ? "Remove Vault Protection" : "Set as Vault (Touch ID)") {
                    onToggleVault()
                    if !folder.isVault {
                        // Becoming vault — collapse and lock
                        isExpanded = false
                        isVaultUnlocked = false
                    }
                }
                Divider()
                Button("Rename") {
                    editedTitle = folder.title
                    isEditing = true
                }
                Button("Delete", role: .destructive) { onDeleteFolder() }
            }

            // Snippet rows (vault folders require auth to see snippets)
            if isExpanded && (!folder.isVault || isVaultUnlocked) {
                ForEach(folder.snippets) { snippet in
                    SnippetItemRow(
                        snippet: snippet,
                        isSelected: selectedSnippetID == snippet.id,
                        onSelect: { onSelectSnippet(snippet) },
                        onDelete: { onDeleteSnippet(snippet) },
                        onToggle: { onToggleSnippet(snippet) }
                    )
                }
            }
        }
    }
}

// MARK: - Snippet Item Row
struct SnippetItemRow: View {
    let snippet: SnippetsEditorViewModel.SnippetItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Spacer().frame(width: 14)

            Image(systemName: snippet.isScript ? (snippet.enabled ? "terminal.fill" : "terminal") : (snippet.enabled ? "doc.text.fill" : "doc.text"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : snippet.enabled ? AnyShapeStyle(snippet.isScript ? SwiftUI.Color.green : SwiftUI.Color.blue) : AnyShapeStyle(.quaternary))
                .frame(width: 22, height: 22)
                .background(
                    isSelected
                        ? AnyShapeStyle(.white.opacity(0.15))
                        : AnyShapeStyle(snippet.enabled ? (snippet.isScript ? SwiftUI.Color.green : SwiftUI.Color.blue).opacity(0.08) : SwiftUI.Color.clear)
                )
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(snippet.title.isEmpty ? "Untitled" : snippet.title)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : snippet.enabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                    .lineLimit(1)

                if !snippet.content.isEmpty {
                    Text(snippet.content.prefix(60).replacingOccurrences(of: "\n", with: " "))
                        .font(.system(size: 9))
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.5)) : AnyShapeStyle(.quaternary))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 2)

            if isHovered {
                Button { onDelete() } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            isSelected
                ? AnyShapeStyle(SwiftUI.Color.accentColor.opacity(0.75))
                : isHovered
                    ? AnyShapeStyle(.white.opacity(0.04))
                    : AnyShapeStyle(SwiftUI.Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
        .contextMenu {
            Button(snippet.enabled ? "Disable" : "Enable") { onToggle() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}

// MARK: - Toolbar Button
struct SnippetToolbarButton: View {
    let icon: String
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .frame(width: 24, height: 24)
                .background(isHovered ? .white.opacity(0.08) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) { isHovered = hovering }
        }
    }
}

// MARK: - Window Controller
class ModernSnippetsWindowController: NSWindowController {
    static let shared = ModernSnippetsWindowController()
    private var keyMonitor: Any?

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 740, height: 520),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        window.title = "Snippets"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.minSize = NSSize(width: 600, height: 400)
        window.center()
        window.collectionBehavior = .canJoinAllSpaces

        super.init(window: window)

        let hostView = NSHostingView(rootView: ModernSnippetsEditorView(onClose: { [weak self] in
            self?.close()
        }))
        window.contentView = hostView
        window.delegate = self
        DispatchQueue.main.async {
            hostView.wantsLayer = true
            hostView.layer?.backgroundColor = .clear
            hostView.layer?.isOpaque = false
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        let hostView = NSHostingView(rootView: ModernSnippetsEditorView(onClose: { [weak self] in
            self?.close()
        }))
        window?.contentView = hostView
        DispatchQueue.main.async {
            hostView.wantsLayer = true
            hostView.layer?.backgroundColor = .clear
            hostView.layer?.isOpaque = false
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.close()
                return nil
            }
            return event
        }
    }

    override func close() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        super.close()
    }
}

extension ModernSnippetsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.Notification.closeSnippetEditor), object: nil)
        NSApp.deactivate()
    }
}

// MARK: - Snippet Template Gallery

struct SnippetTemplateGalleryView: View {
    @ObservedObject var viewModel: SnippetsEditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let template = viewModel.pendingTemplate {
                // Parameter configuration form
                templateConfigView(template)
            } else {
                // Template browser
                templateBrowser
            }
        }
        .frame(width: 480, height: 440)
        .background(.regularMaterial)
    }

    // MARK: - Template Browser

    private var templateBrowser: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.blue)
                Text("Script Templates")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button { viewModel.showingTemplates = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider().opacity(0.3)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(SnippetTemplateLibrary.categories, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(category.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            ForEach(SnippetTemplateLibrary.templates(in: category)) { template in
                                templateRow(template)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    private func templateRow(_ template: SnippetTemplate) -> some View {
        HStack(spacing: 10) {
            Image(systemName: template.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.green)
                .frame(width: 28, height: 28)
                .background(SwiftUI.Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(template.name)
                        .font(.system(size: 12, weight: .medium))
                    if template.hasParameters {
                        Text("\(template.parameters.count) fields")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(SwiftUI.Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                Text(template.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                if template.hasParameters {
                    // Show config form
                    var defaults = [String: String]()
                    for param in template.parameters {
                        defaults[param.key] = param.defaultValue
                    }
                    viewModel.pendingTemplateValues = defaults
                    viewModel.pendingTemplate = template
                } else {
                    // Install directly
                    viewModel.installTemplate(template)
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: template.hasParameters ? "slider.horizontal.3" : "plus")
                        .font(.system(size: 9, weight: .bold))
                    Text(template.hasParameters ? "Configure" : "Add")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.blue.opacity(0.12))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Parameter Configuration Form

    private func templateConfigView(_ template: SnippetTemplate) -> some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack(spacing: 10) {
                Button {
                    viewModel.pendingTemplate = nil
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Image(systemName: template.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.green)

                Text(template.name)
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                Button { viewModel.showingTemplates = false; viewModel.pendingTemplate = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider().opacity(0.3)

            // Form fields
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(template.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)

                    ForEach(template.parameters) { param in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(param.label)
                                .font(.system(size: 11, weight: .medium))

                            TextField(param.placeholder, text: Binding(
                                get: { viewModel.pendingTemplateValues[param.key] ?? param.defaultValue },
                                set: { viewModel.pendingTemplateValues[param.key] = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                        }
                    }

                    // Preview of resolved script
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preview")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text(template.resolvedContent(with: viewModel.pendingTemplateValues))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(12)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.black.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            }

            Divider().opacity(0.3)

            // Footer with Create button
            HStack {
                Text("Recommended: place in a Vault folder for Touch ID protection")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)

                Spacer()

                Button {
                    viewModel.installTemplate(template, values: viewModel.pendingTemplateValues)
                    viewModel.pendingTemplate = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 11))
                        Text("Create Snippet")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}
