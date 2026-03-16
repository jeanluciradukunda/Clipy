// swiftlint:disable file_length
//
//  ModernSnippetsEditor.swift
//
//  Clipy Dev
//
//  Modern SwiftUI snippets editor — liquid glass design matching the search panel.
//

import SwiftUI
import RealmSwift
import AEXML
import UniformTypeIdentifiers
import LocalAuthentication

// MARK: - Snippets ViewModel
@MainActor
class SnippetsEditorViewModel: ObservableObject {
    @Published var folders = [FolderItem]()
    @Published var selectedFolderID: String?
    @Published var selectedSnippetID: String?
    @Published var editingTitle = ""
    @Published var editingContent = ""
    @Published var sidebarFilter = ""
    @Published var hasUnsavedChanges = false

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
    }

    func load() {
        guard let realm = Realm.safeInstance() else { return }
        let results = realm.objects(CPYFolder.self)
            .sorted(byKeyPath: #keyPath(CPYFolder.index), ascending: true)

        folders = results.map { folder in
            let snippets = folder.snippets
                .sorted(byKeyPath: #keyPath(CPYSnippet.index), ascending: true)
                .map { snippet in
                    SnippetItem(id: snippet.identifier, title: snippet.title, content: snippet.content, enabled: snippet.enable)
                }
            return FolderItem(id: folder.identifier, title: folder.title, enabled: folder.enable, isVault: folder.isVault, snippets: Array(snippets))
        }

        if selectedFolderID == nil {
            selectedFolderID = folders.first?.id
        }

        if let snippetID = selectedSnippetID {
            if let folder = folders.first(where: { $0.snippets.contains(where: { $0.id == snippetID }) }),
               let snippet = folder.snippets.first(where: { $0.id == snippetID }) {
                editingTitle = snippet.title
                editingContent = snippet.content
                hasUnsavedChanges = false
            }
        }
    }

    func selectSnippet(_ snippet: SnippetItem) {
        if hasUnsavedChanges { saveCurrentSnippet() }
        selectedSnippetID = snippet.id
        editingTitle = snippet.title
        editingContent = snippet.content
        hasUnsavedChanges = false
    }

    func saveCurrentSnippet() {
        guard let snippetID = selectedSnippetID else { return }
        guard let realm = Realm.safeInstance() else { return }
        guard let snippet = realm.object(ofType: CPYSnippet.self, forPrimaryKey: snippetID) else { return }
        realm.transaction {
            snippet.title = editingTitle
            snippet.content = editingContent
        }
        hasUnsavedChanges = false
        load()
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

    // MARK: - Import / Export

    func exportSnippets() {
        let xmlDocument = AEXMLDocument()
        let rootElement = xmlDocument.addChild(name: Constants.Xml.rootElement)

        guard let realm = Realm.safeInstance() else { return }
        let realmFolders = realm.objects(CPYFolder.self)
            .sorted(byKeyPath: #keyPath(CPYFolder.index), ascending: true)

        realmFolders.forEach { folder in
            let folderElement = rootElement.addChild(name: Constants.Xml.folderElement)
            folderElement.addChild(name: Constants.Xml.titleElement, value: folder.title)
            let snippetsElement = folderElement.addChild(name: Constants.Xml.snippetsElement)
            folder.snippets
                .sorted(byKeyPath: #keyPath(CPYSnippet.index), ascending: true)
                .forEach { snippet in
                    let snippetElement = snippetsElement.addChild(name: Constants.Xml.snippetElement)
                    snippetElement.addChild(name: Constants.Xml.titleElement, value: snippet.title)
                    snippetElement.addChild(name: Constants.Xml.contentElement, value: snippet.content)
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

            xmlDocument[Constants.Xml.rootElement].children.forEach { folderElement in
                let folder = CPYFolder()
                folder.title = folderElement[Constants.Xml.titleElement].value ?? "untitled folder"
                folder.index = folderIndex
                realm.transaction { realm.add(folder) }

                var snippetIndex = 0
                folderElement[Constants.Xml.snippetsElement][Constants.Xml.snippetElement]
                    .all?
                    .forEach { snippetElement in
                        let snippet = CPYSnippet()
                        snippet.title = snippetElement[Constants.Xml.titleElement].value ?? "untitled snippet"
                        snippet.content = snippetElement[Constants.Xml.contentElement].value ?? ""
                        snippet.index = snippetIndex
                        realm.transaction { folder.snippets.append(snippet) }
                        snippetIndex += 1
                    }
                folderIndex += 1
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
        .onAppear { viewModel.load() }
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
                            onToggleVault: { viewModel.toggleVault(folder.id) }
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
        HStack(spacing: 8) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 26, height: 26)
                .background(.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            TextField("Snippet title", text: $viewModel.editingTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium))
                .onChange(of: viewModel.editingTitle) { _, _ in
                    viewModel.hasUnsavedChanges = true
                }

            Spacer()

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
    }

    private var editorBody: some View {
        TextEditor(text: $viewModel.editingContent)
            .font(.system(size: 13, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .onChange(of: viewModel.editingContent) { _, _ in
                viewModel.hasUnsavedChanges = true
            }
    }

    private var variablesBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
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
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
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

    @State private var isExpanded: Bool
    @State private var isEditing = false
    @State private var editedTitle = ""
    @State private var isHovered = false
    @State private var isVaultUnlocked = false

    init(folder: SnippetsEditorViewModel.FolderItem, isSelected: Bool, selectedSnippetID: String?,
         onSelectFolder: @escaping () -> Void, onSelectSnippet: @escaping (SnippetsEditorViewModel.SnippetItem) -> Void,
         onAddSnippet: @escaping () -> Void, onDeleteFolder: @escaping () -> Void,
         onDeleteSnippet: @escaping (SnippetsEditorViewModel.SnippetItem) -> Void,
         onToggleFolder: @escaping () -> Void, onToggleSnippet: @escaping (SnippetsEditorViewModel.SnippetItem) -> Void,
         onRenameFolder: @escaping (String) -> Void, onToggleVault: @escaping () -> Void) {
        self.folder = folder
        self.isSelected = isSelected
        self.selectedSnippetID = selectedSnippetID
        self.onSelectFolder = onSelectFolder
        self.onSelectSnippet = onSelectSnippet
        self.onAddSnippet = onAddSnippet
        self.onDeleteFolder = onDeleteFolder
        self.onDeleteSnippet = onDeleteSnippet
        self.onToggleFolder = onToggleFolder
        self.onToggleSnippet = onToggleSnippet
        self.onRenameFolder = onRenameFolder
        self.onToggleVault = onToggleVault
        // Vault folders start collapsed
        _isExpanded = State(initialValue: !folder.isVault)
    }

    var body: some View {
        VStack(spacing: 1) {
            // Folder header
            HStack(spacing: 6) {
                Button {
                    if folder.isVault && !isVaultUnlocked && !isExpanded {
                        VaultAuthService.shared.authenticate(folderID: folder.id, reason: "Unlock \"\(folder.title)\" vault") { success in
                            if success {
                                isVaultUnlocked = true
                                withAnimation(.easeOut(duration: 0.15)) { isExpanded = true }
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

            Image(systemName: snippet.enabled ? "doc.text.fill" : "doc.text")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : snippet.enabled ? AnyShapeStyle(.blue) : AnyShapeStyle(.quaternary))
                .frame(width: 22, height: 22)
                .background(
                    isSelected
                        ? AnyShapeStyle(.white.opacity(0.15))
                        : AnyShapeStyle(snippet.enabled ? SwiftUI.Color.blue.opacity(0.08) : SwiftUI.Color.clear)
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

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 740, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: true
        )
        window.title = "Snippets"
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 600, height: 400)
        window.center()
        window.collectionBehavior = .canJoinAllSpaces

        super.init(window: window)

        window.contentView = NSHostingView(rootView: ModernSnippetsEditorView(onClose: { [weak self] in
            self?.close()
        }))
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        window?.contentView = NSHostingView(rootView: ModernSnippetsEditorView(onClose: { [weak self] in
            self?.close()
        }))
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension ModernSnippetsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.Notification.closeSnippetEditor), object: nil)
        NSApp.deactivate()
    }
}
