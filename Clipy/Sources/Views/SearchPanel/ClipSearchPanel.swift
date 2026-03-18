// swiftlint:disable file_length
//
//  ClipSearchPanel.swift
//
//  Clipy
//
//  Spotlight/Raycast-caliber clipboard history panel.
//  Split-pane: results list + rich preview + text transforms.
//

import SwiftUI
import RealmSwift
import Combine
import TipKit

// MARK: - Content Filter
enum ClipFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case text = "Text"
    case images = "Images"
    case links = "Links"
    case files = "Files"
    case pinned = "Pinned"
    case queue = "Queue"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .text: return "doc.plaintext"
        case .images: return "photo"
        case .links: return "link"
        case .files: return "doc.on.doc"
        case .pinned: return "pin.fill"
        case .queue: return "tray.and.arrow.down"
        }
    }

    func matches(_ clip: ClipItemViewModel) -> Bool {
        switch self {
        case .all: return true
        case .text:
            let type = NSPasteboard.PasteboardType(rawValue: clip.primaryType)
            return type.isStringType() || type.isRTFType() || type.isRTFDType()
        case .images:
            let type = NSPasteboard.PasteboardType(rawValue: clip.primaryType)
            return type.isTIFFType()
        case .links:
            let type = NSPasteboard.PasteboardType(rawValue: clip.primaryType)
            return type.isURLType() || clip.fullText.hasPrefix("http")
        case .files:
            let type = NSPasteboard.PasteboardType(rawValue: clip.primaryType)
            return type.isFilenamesType()
        case .pinned:
            return clip.isPinned
        case .queue:
            return false // Queue uses its own data source
        }
    }
}

// MARK: - ClipItem ViewModel
struct ClipItemViewModel: Identifiable, Hashable {
    private static let shortDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        return fmt
    }()

    let id: String
    let title: String
    let fullText: String
    let primaryType: String
    let updateTime: Date
    let isPinned: Bool
    let isColorCode: Bool
    let thumbnailKey: String
    let dataHash: String

    var pasteboardType: NSPasteboard.PasteboardType {
        NSPasteboard.PasteboardType(rawValue: primaryType)
    }

    var displayTitle: String {
        if pasteboardType.isTIFFType() { return "Image" }
        if pasteboardType.isPDFType() { return "PDF Document" }
        if pasteboardType.isFilenamesType() && title.isEmpty { return "File Reference" }
        return title.isEmpty ? "Empty" : title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var previewLine: String {
        let clean = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return "" }
        let collapsed = clean.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .joined(separator: " \u{2022} ")
        return String(collapsed.prefix(200))
    }

    var timeAgo: String {
        let secs = Date().timeIntervalSince(updateTime)
        if secs < 60 { return "now" }
        if secs < 3600 { return "\(Int(secs / 60))m" }
        if secs < 86400 { return "\(Int(secs / 3600))h" }
        if secs < 604800 { return "\(Int(secs / 86400))d" }
        return Self.shortDateFormatter.string(from: updateTime)
    }

    var isImage: Bool { pasteboardType.isTIFFType() }

    var typeIconName: String {
        if pasteboardType.isTIFFType() { return "photo" }
        if pasteboardType.isPDFType() { return "doc.richtext" }
        if pasteboardType.isFilenamesType() { return "doc.on.doc" }
        if pasteboardType.isURLType() || fullText.hasPrefix("http") { return "link" }
        if isColorCode { return "paintpalette.fill" }
        if looksLikeCode { return "chevron.left.forwardslash.chevron.right" }
        return "doc.plaintext"
    }

    var typeColor: SwiftUI.Color {
        if pasteboardType.isTIFFType() { return .blue }
        if pasteboardType.isPDFType() { return .red }
        if pasteboardType.isFilenamesType() { return .green }
        if pasteboardType.isURLType() || fullText.hasPrefix("http") { return .purple }
        if isColorCode { return .orange }
        if looksLikeCode { return .cyan }
        return .gray
    }

    var looksLikeCode: Bool {
        let indicators = ["func ", "class ", "import ", "var ", "let ", "def ", "return ",
                          "const ", "function ", "if (", "for (", "while (", "=> {",
                          "#!/", "<div", "<html", "SELECT ", "INSERT ", "CREATE "]
        let text = fullText.prefix(500)
        return indicators.contains { text.contains($0) }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ClipItemViewModel, rhs: ClipItemViewModel) -> Bool { lhs.id == rhs.id }
}

// MARK: - ViewModel
@MainActor
class ClipSearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var clips = [ClipItemViewModel]()
    @Published var selectedIndex = 0
    @Published var selectedIndices: Set<Int> = [0]
    @Published var activeFilter: ClipFilter = .all
    @Published var ocrText: String?
    @Published var isRunningOCR = false

    private var allClips = [ClipItemViewModel]()
    private var cancellables = Set<AnyCancellable>()

    // Two-digit quick select: type "1" then "5" quickly to select item 15
    var digitBuffer = ""
    var digitTimer: DispatchWorkItem?

    func handleDigitPress(_ digit: Character) {
        digitTimer?.cancel()
        digitBuffer.append(digit)

        if digitBuffer.count >= 2 {
            // Two digits entered — select immediately
            if let num = Int(digitBuffer) {
                let index = num - 1
                if index >= 0 && index < clips.count {
                    selectedIndex = index
                    selectedIndices = [index]
                    pasteSelected()
                }
            }
            digitBuffer = ""
            return
        }

        // Wait briefly for a second digit
        let timer = DispatchWorkItem { [weak self] in
            guard let self, !self.digitBuffer.isEmpty else { return }
            if let num = Int(self.digitBuffer) {
                let index = num - 1
                if index >= 0 && index < self.clips.count {
                    self.selectedIndex = index
                    self.selectedIndices = [index]
                    self.pasteSelected()
                }
            }
            self.digitBuffer = ""
        }
        digitTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: timer)
    }

    init() {
        // React to search text or filter changes
        Publishers.CombineLatest($searchText.debounce(for: .milliseconds(60), scheduler: DispatchQueue.main), $activeFilter)
            .sink { [weak self] query, filter in
                self?.applyFilter(query: query, filter: filter)
            }
            .store(in: &cancellables)
    }

    func loadClips() {
        guard let realm = Realm.safeInstance() else { return }
        let results = realm.objects(CPYClip.self)
            .sorted(byKeyPath: #keyPath(CPYClip.updateTime), ascending: false)

        allClips = results.compactMap { clip in
            var searchableText = clip.title
            if searchableText.isEmpty {
                let path = clip.dataPath
                if !path.isEmpty, let data = NSKeyedUnarchiver.unarchiveObject(withFile: path) as? CPYClipData {
                    if !data.stringValue.isEmpty {
                        searchableText = data.stringValue
                    }
                }
            }
            return ClipItemViewModel(
                id: clip.dataHash,
                title: clip.title,
                fullText: searchableText,
                primaryType: clip.primaryType,
                updateTime: Date(timeIntervalSince1970: TimeInterval(clip.updateTime)),
                isPinned: clip.isPinned,
                isColorCode: clip.isColorCode,
                thumbnailKey: clip.thumbnailPath,
                dataHash: clip.dataHash
            )
        }

        allClips.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.updateTime > rhs.updateTime
        }

        applyFilter(query: searchText, filter: activeFilter)
    }

    func applyFilter(query: String, filter: ClipFilter) {
        var filtered = allClips
        // Apply type filter
        if filter != .all {
            filtered = filtered.filter { filter.matches($0) }
        }
        // Apply search
        if !query.isEmpty {
            let terms = query.lowercased().split(separator: " ").map(String.init)
            filtered = filtered.filter { clip in
                let haystack = (clip.fullText + " " + clip.displayTitle).lowercased()
                return terms.allSatisfy { haystack.contains($0) }
            }
        }
        clips = filtered
        selectedIndex = clips.isEmpty ? 0 : min(selectedIndex, clips.count - 1)
        selectedIndices = [selectedIndex]
    }

    func moveSelection(by offset: Int) {
        guard !clips.isEmpty else { return }
        selectedIndex = max(0, min(clips.count - 1, selectedIndex + offset))
        selectedIndices = [selectedIndex]
        ocrText = nil
    }

    func extendSelection(by offset: Int) {
        guard !clips.isEmpty else { return }
        let newIndex = max(0, min(clips.count - 1, selectedIndex + offset))
        guard newIndex != selectedIndex else { return }
        selectedIndex = newIndex
        selectedIndices.insert(newIndex)
    }

    func selectedClip() -> ClipItemViewModel? {
        guard clips.indices.contains(selectedIndex) else { return nil }
        return clips[selectedIndex]
    }

    func pasteSelected() {
        guard let clip = selectedClip() else { return }
        guard let realm = Realm.safeInstance() else { return }
        guard let realmClip = realm.object(ofType: CPYClip.self, forPrimaryKey: clip.dataHash) else { return }
        // Copy to pasteboard, then dismiss panel and paste into the previous app
        AppEnvironment.current.pasteService.copyToPasteboard(with: realmClip)
        ClipSearchWindowController.shared.dismissAndPaste()
    }

    func pasteAsPlainText() {
        guard let clip = selectedClip() else { return }
        let text = clip.fullText.isEmpty ? clip.displayTitle : clip.fullText
        // Put plain text on clipboard using standard .string type
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        ClipSearchWindowController.shared.dismissAndPaste()
    }

    func copyTransformed(_ transform: (String) -> String) {
        guard let clip = selectedClip() else { return }
        let text = clip.fullText.isEmpty ? clip.displayTitle : clip.fullText
        let transformed = transform(text)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transformed, forType: .string)
    }

    func togglePin() {
        guard let clip = selectedClip() else { return }
        guard let realm = Realm.safeInstance() else { return }
        guard let realmClip = realm.object(ofType: CPYClip.self, forPrimaryKey: clip.dataHash) else { return }
        AppEnvironment.current.clipService.togglePin(for: realmClip)
        loadClips()
    }

    func deleteSelected() {
        guard let realm = Realm.safeInstance() else { return }
        let indicesToDelete = selectedIndices.sorted(by: >)
        for idx in indicesToDelete {
            guard clips.indices.contains(idx) else { continue }
            let clip = clips[idx]
            guard let realmClip = realm.object(ofType: CPYClip.self, forPrimaryKey: clip.dataHash) else { continue }
            AppEnvironment.current.clipService.delete(with: realmClip)
        }
        loadClips()
    }

    func runOCR() {
        guard let clip = selectedClip() else { return }
        guard let realm = Realm.safeInstance() else { return }
        guard let realmClip = realm.object(ofType: CPYClip.self, forPrimaryKey: clip.dataHash) else { return }
        guard let data = NSKeyedUnarchiver.unarchiveObject(withFile: realmClip.dataPath) as? CPYClipData,
              let image = data.image else { return }
        isRunningOCR = true
        ocrText = nil
        OCRService.recognizeText(in: image) { [weak self] text in
            self?.ocrText = text
            self?.isRunningOCR = false
        }
    }

    func shareImage(from view: NSView) {
        guard let clip = selectedClip() else { return }
        guard let realm = Realm.safeInstance() else { return }
        guard let realmClip = realm.object(ofType: CPYClip.self, forPrimaryKey: clip.dataHash) else { return }
        guard let data = NSKeyedUnarchiver.unarchiveObject(withFile: realmClip.dataPath) as? CPYClipData,
              let image = data.image else { return }
        let picker = NSSharingServicePicker(items: [image])
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }

    func shareSelectedImage() {
        guard let clip = selectedClip(), clip.pasteboardType.isTIFFType() else { return }
        guard let realm = Realm.safeInstance() else { return }
        guard let realmClip = realm.object(ofType: CPYClip.self, forPrimaryKey: clip.dataHash) else { return }
        guard let data = NSKeyedUnarchiver.unarchiveObject(withFile: realmClip.dataPath) as? CPYClipData,
              let image = data.image else { return }
        guard let view = ClipSearchWindowController.shared.window?.contentView else { return }
        let picker = NSSharingServicePicker(items: [image])
        picker.show(relativeTo: CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1), of: view, preferredEdge: .minY)
    }

    func copyString(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    func reset() {
        searchText = ""
        selectedIndex = 0
        selectedIndices = [0]
        activeFilter = .all
        loadClips()
    }
}

// MARK: - Main Panel View
// swiftlint:disable:next type_body_length
struct ClipSearchPanelView: View {
    @StateObject private var viewModel = ClipSearchViewModel()
    @ObservedObject private var queueService = ClipboardQueueService.shared
    @ObservedObject private var shortcuts = PanelShortcutService.shared
    @FocusState private var isSearchFocused: Bool
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar
            Divider().opacity(0.4)
            // Filter chips
            filterBar
            Divider().opacity(0.4)
            // Content
            if viewModel.activeFilter == .queue {
                QueueContentView(onDismiss: onDismiss)
            } else {
                // Split content: list + preview
                HStack(spacing: 0) {
                    resultsList
                        .frame(width: 310)
                        .frame(maxHeight: .infinity)
                    Divider().opacity(0.4)
                    previewPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity)
            }
            Divider().opacity(0.4)
            footerBar
        }
        .frame(width: 720, height: 520)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
        .onAppear {
            viewModel.reset()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFocused = true
            }
        }
        .onKeyPress(.upArrow, phases: [.down, .repeat]) { press in
            if press.modifiers.contains(.shift) { viewModel.extendSelection(by: -1); return .handled }
            viewModel.moveSelection(by: -1); return .handled
        }
        .onKeyPress(.downArrow, phases: [.down, .repeat]) { press in
            if press.modifiers.contains(.shift) { viewModel.extendSelection(by: 1); return .handled }
            viewModel.moveSelection(by: 1); return .handled
        }
        .onKeyPress(.escape) { onDismiss(); return .handled }
        // Customizable panel shortcuts
        .onKeyPress(phases: .down) { press in
            if shortcuts.matches(press, shortcut: shortcuts.pastePlain) {
                viewModel.pasteAsPlainText()
                return .handled
            }
            if shortcuts.matches(press, shortcut: shortcuts.pin) {
                viewModel.togglePin()
                return .handled
            }
            if shortcuts.matches(press, shortcut: shortcuts.delete) {
                viewModel.deleteSelected()
                return .handled
            }
            if shortcuts.matches(press, shortcut: shortcuts.paste) {
                viewModel.pasteSelected()
                return .handled
            }
            if shortcuts.matches(press, shortcut: shortcuts.ocr) {
                viewModel.runOCR()
                return .handled
            }
            if shortcuts.matches(press, shortcut: shortcuts.share) {
                viewModel.shareSelectedImage()
                return .handled
            }
            return .ignored
        }
        // Number keys for quick paste — type one digit or two digits quickly (e.g. "15" for item 15)
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
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(.secondary)

            TextField("Search\u{2026}", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .light))
                .focused($isSearchFocused)

            if !viewModel.searchText.isEmpty {
                Button { viewModel.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .popoverTip(QuickSelectTip(), arrowEdge: .bottom)
    }

    // MARK: - Filter Bar
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ClipFilter.allCases) { filter in
                    FilterChip(
                        filter: filter,
                        isActive: viewModel.activeFilter == filter,
                        count: countFor(filter)
                    ) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            viewModel.activeFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .popoverTip(FiltersTip(), arrowEdge: .bottom)
    }

    private func countFor(_ filter: ClipFilter) -> Int? {
        if filter == .all { return nil }
        // Use allClips count through the viewModel's filtering
        return nil // Don't show counts to keep it clean
    }

    // MARK: - Results List
    private var resultsList: some View {
        Group {
            if viewModel.clips.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: viewModel.searchText.isEmpty ? "clipboard" : "magnifyingglass")
                        .font(.system(size: 28, weight: .ultraLight))
                        .foregroundStyle(.quaternary)
                    Text(viewModel.searchText.isEmpty ? "Empty" : "No matches")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(Array(viewModel.clips.enumerated()), id: \.element.id) { index, clip in
                                ClipRowView(clip: clip, isSelected: viewModel.selectedIndices.contains(index), rank: index + 1) {
                                    viewModel.selectedIndex = index
                                    viewModel.selectedIndices = [index]
                                    viewModel.deleteSelected()
                                }
                                    .id(clip.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        viewModel.selectedIndex = index
                                        viewModel.selectedIndices = [index]
                                    }
                                    .onTapGesture(count: 2) {
                                        viewModel.selectedIndex = index
                                        viewModel.selectedIndices = [index]
                                        viewModel.pasteSelected()
                                    }
                            }
                        }
                        .padding(6)
                    }
                    .onChange(of: viewModel.selectedIndex) { _, newValue in
                        if let clip = viewModel.clips[safe: newValue] {
                            withAnimation(.easeOut(duration: 0.08)) {
                                proxy.scrollTo(clip.id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Preview Pane
    private var previewPane: some View {
        Group {
            if let clip = viewModel.selectedClip() {
                VStack(alignment: .leading, spacing: 0) {
                    // Preview header
                    HStack(spacing: 8) {
                        Image(systemName: clip.typeIconName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(clip.typeColor)
                        Text(clip.displayTitle)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        // Language badge for code content
                        if clip.looksLikeCode || !clip.fullText.isEmpty {
                            let lang = LanguageDetector.detect(clip.fullText)
                            if lang != .plainText {
                                HStack(spacing: 3) {
                                    Image(systemName: lang.icon)
                                        .font(.system(size: 8))
                                    Text(lang.rawValue)
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .foregroundStyle(.secondary)
                            }
                        }
                        Text(clip.timeAgo)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        if clip.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider().opacity(0.3)

                    // Preview content
                    ScrollView {
                        previewContent(for: clip)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Detected content badges
                    detectedContentBadges(for: clip)

                    Divider().opacity(0.3)

                    // Action buttons
                    actionBar(for: clip)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "eye")
                        .font(.system(size: 28, weight: .ultraLight))
                        .foregroundStyle(.quaternary)
                    Text("Select a clip to preview")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(.black.opacity(0.03))
    }

    @ViewBuilder
    private func previewContent(for clip: ClipItemViewModel) -> some View {
        if clip.pasteboardType.isTIFFType() {
            // Image preview + OCR
            VStack(spacing: 8) {
                if let nsImage = Self.loadImage(for: clip) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    Label("Image data", systemImage: "photo")
                        .foregroundStyle(.secondary)
                }

                if viewModel.isRunningOCR {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Extracting text...")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                } else if let ocrText = viewModel.ocrText {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label("Extracted Text", systemImage: "text.viewfinder")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                viewModel.copyString(ocrText)
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)
                        }
                        Text(ocrText)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.85))
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.black.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        } else if clip.isColorCode {
            // Color preview
            HStack(spacing: 12) {
                if let color = NSColor(hexString: clip.fullText) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(SwiftUI.Color(nsColor: color))
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(.primary.opacity(0.1), lineWidth: 0.5)
                        )
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(clip.fullText)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                    Text("Color")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            // Text preview with syntax highlighting
            let text = clip.fullText.isEmpty ? clip.displayTitle : clip.fullText
            let language = LanguageDetector.detect(text)
            if language != .plainText {
                let highlighted = SyntaxHighlighter().highlight(text, language: language)
                Text(highlighted)
                    .textSelection(.enabled)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            } else if clip.pasteboardType.isURLType() || (text.hasPrefix("http") && URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) != nil) {
                // Clickable URL preview
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                Text(trimmed)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.blue)
                    .underline()
                    .textSelection(.enabled)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .onTapGesture {
                        if let url = URL(string: trimmed) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .help("Open in browser")
            } else {
                Text(text)
                    .font(.system(size: 13, design: clip.looksLikeCode ? .monospaced : .default))
                    .foregroundStyle(.primary.opacity(0.85))
                    .textSelection(.enabled)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Load full-resolution image for a clip, falling back to disk if cache is empty
    static func loadImage(for clip: ClipItemViewModel) -> NSImage? {
        if !clip.thumbnailKey.isEmpty, let cached = ClipService.cachedThumbnail(forKey: clip.thumbnailKey) {
            return cached
        }
        guard let realm = Realm.safeInstance() else { return nil }
        guard let realmClip = realm.object(ofType: CPYClip.self, forPrimaryKey: clip.dataHash) else { return nil }
        guard let data = NSKeyedUnarchiver.unarchiveObject(withFile: realmClip.dataPath) as? CPYClipData,
              let image = data.image else { return nil }
        if !clip.thumbnailKey.isEmpty {
            ClipService.cacheThumbnail(image, forKey: clip.thumbnailKey)
        }
        return image
    }

    @ViewBuilder
    private func detectedContentBadges(for clip: ClipItemViewModel) -> some View {
        let text = clip.fullText.isEmpty ? clip.displayTitle : clip.fullText
        let detected = clip.pasteboardType.isTIFFType() ? [] : ContentDetector.detect(in: text)
        if !detected.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(detected.prefix(6))) { item in
                        HStack(spacing: 4) {
                            Image(systemName: item.type.icon)
                                .font(.system(size: 9))
                            Text(item.value.count > 30 ? String(item.value.prefix(30)) + "..." : item.value)
                                .font(.system(size: 10, design: .monospaced))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(item.type.color.opacity(0.1))
                        .foregroundStyle(item.type.color)
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                        .onTapGesture {
                            switch item.type {
                            case .url:
                                if let url = URL(string: item.value) { NSWorkspace.shared.open(url) }
                            case .email:
                                if let url = URL(string: "mailto:\(item.value)") { NSWorkspace.shared.open(url) }
                            case .phoneNumber:
                                if let url = URL(string: "tel:\(item.value)") { NSWorkspace.shared.open(url) }
                            case .ipAddress:
                                viewModel.copyString(item.value)
                            }
                        }
                        .help(item.type == .url ? "Open in browser" : item.type == .email ? "Compose email" : item.type == .phoneNumber ? "Call" : "Copy")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
        }
    }

    private func actionBar(for clip: ClipItemViewModel) -> some View {
        let text = clip.fullText.isEmpty ? clip.displayTitle : clip.fullText
        let detected = clip.pasteboardType.isTIFFType() ? [] : ContentDetector.detect(in: text)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ActionButton(label: "Paste", icon: "doc.on.clipboard", shortcut: shortcuts.paste.label) {
                    viewModel.pasteSelected()
                }
                ActionButton(label: "Plain Text", icon: "textformat", shortcut: shortcuts.pastePlain.label) {
                    viewModel.pasteAsPlainText()
                }
                .popoverTip(PlainTextTip(), arrowEdge: .bottom)

                // OCR + Share for images
                if clip.pasteboardType.isTIFFType() {
                    Divider().frame(height: 16).opacity(0.3)
                    ActionButton(label: "OCR", icon: "text.viewfinder", shortcut: shortcuts.ocr.label) {
                        viewModel.runOCR()
                    }
                    .popoverTip(OCRTip(), arrowEdge: .bottom)
                    ShareActionButton { anchorView in
                        viewModel.shareImage(from: anchorView)
                    }
                }

                // Text transforms (non-image)
                if !clip.pasteboardType.isTIFFType() {
                    Divider().frame(height: 16).opacity(0.3)

                    ActionButton(label: "UPPER", icon: "textformat.size.larger") {
                        viewModel.copyTransformed { $0.uppercased() }
                    }
                    ActionButton(label: "lower", icon: "textformat.size.smaller") {
                        viewModel.copyTransformed { $0.lowercased() }
                    }
                    ActionButton(label: "Title", icon: "textformat") {
                        viewModel.copyTransformed { $0.capitalized }
                    }
                }

                // Format JSON
                if LanguageDetector.isValidJSON(clip.fullText.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    Divider().frame(height: 16).opacity(0.3)
                    ActionButton(label: "Format", icon: "curlybraces") {
                        viewModel.copyTransformed { JSONFormatter.prettyPrint($0) ?? $0 }
                    }
                    ActionButton(label: "Minify", icon: "arrow.down.right.and.arrow.up.left") {
                        viewModel.copyTransformed { JSONFormatter.minify($0) ?? $0 }
                    }
                }

                // Link sanitization
                if LinkSanitizer.hasTrackingParams(text) {
                    Divider().frame(height: 16).opacity(0.3)
                    ActionButton(label: "Clean URL", icon: "link.badge.plus") {
                        if let cleaned = LinkSanitizer.sanitize(text) {
                            viewModel.copyString(cleaned)
                        }
                    }
                }

                // Actionable clips — contextual buttons for detected content
                if !detected.isEmpty {
                    Divider().frame(height: 16).opacity(0.3)
                    ForEach(Array(detected.prefix(4))) { item in
                        switch item.type {
                        case .url:
                            ActionButton(label: "Open", icon: "safari") {
                                if let url = URL(string: item.value) {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        case .email:
                            ActionButton(label: "Mail", icon: "envelope") {
                                if let url = URL(string: "mailto:\(item.value)") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        case .ipAddress:
                            ActionButton(label: "Copy IP", icon: "network") {
                                viewModel.copyString(item.value)
                            }
                        case .phoneNumber:
                            ActionButton(label: "Call", icon: "phone") {
                                if let url = URL(string: "tel:\(item.value)") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Footer
    private var footerBar: some View {
        HStack(spacing: 16) {
            kbHint(shortcuts.paste.label, "paste")
            kbHint(shortcuts.pastePlain.label, "plain")
            kbHint(shortcuts.pin.label, "pin")
            kbHint(shortcuts.delete.label, "delete")
            kbHint(shortcuts.ocr.label, "ocr")
            kbHint(shortcuts.share.label, "share")
            kbHint("\u{21E7}\u{2191}\u{2193}", "select")
            kbHint("1\u{2013}30", "quick")
            Spacer()
            if viewModel.selectedIndices.count > 1 {
                Text("\(viewModel.selectedIndices.count) selected")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
            }
            Text("\(viewModel.clips.count) items")
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

// MARK: - Filter Chip
struct FilterChip: View {
    let filter: ClipFilter
    let isActive: Bool
    let count: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.system(size: 10, weight: .medium))
                Text(filter.rawValue)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? SwiftUI.Color.accentColor.opacity(0.15) : .white.opacity(0.05))
            .foregroundStyle(isActive ? SwiftUI.Color.accentColor : .secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isActive ? SwiftUI.Color.accentColor.opacity(0.3) : .white.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Keyboard Hint (shared across panels)
struct KeyboardHintView: View {
    let key: String
    let label: String

    var body: some View {
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

// MARK: - Action Button
struct ActionButton: View {
    let label: String
    let icon: String
    var shortcut: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share Action Button (bridges NSSharingServicePicker into SwiftUI)
struct ShareActionButton: View {
    let action: (NSView) -> Void

    var body: some View {
        ActionButton(label: "Share", icon: "square.and.arrow.up") {
            // handled by overlay
        }
        .overlay(ShareAnchorView(action: action))
    }
}

private struct ShareAnchorView: NSViewRepresentable {
    let action: (NSView) -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: .zero)
        button.isTransparent = true
        button.target = context.coordinator
        button.action = #selector(Coordinator.clicked(_:))
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    class Coordinator: NSObject {
        let action: (NSView) -> Void
        init(action: @escaping (NSView) -> Void) { self.action = action }
        @objc func clicked(_ sender: NSButton) { action(sender) }
    }
}

// MARK: - Queue Content View
struct QueueContentView: View {
    @ObservedObject private var queue = ClipboardQueueService.shared
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Queue items list
            VStack(spacing: 0) {
                if queue.queue.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: 32, weight: .ultraLight))
                            .foregroundStyle(.quaternary)
                        if queue.isCollecting {
                            Text("Collecting\u{2026}")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("Copy items and they\u{2019}ll appear here")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("Collect Mode")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("Gather multiple copies, paste them all at once")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)

                            Button {
                                queue.startCollecting()
                                onDismiss()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 10))
                                    Text("Start Collecting")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(SwiftUI.Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(queue.queue.enumerated()), id: \.element.id) { index, item in
                                QueueItemRow(item: item, index: index + 1)
                            }
                        }
                        .padding(6)
                    }
                }
            }
            .frame(width: 310)

            Divider().opacity(0.4)

            // Queue actions / preview
            VStack(spacing: 0) {
                if queue.hasItems {
                    // Merged preview
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.blue)
                            Text("Merged Preview")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text("\(queue.itemCount) items")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        Divider().opacity(0.3)

                        ScrollView {
                            Text(queue.mergedPreview)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.primary.opacity(0.85))
                                .textSelection(.enabled)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Divider().opacity(0.3)

                        // Separator picker
                        HStack(spacing: 8) {
                            Text("Join with:")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            ForEach(MergeSeparator.allCases.filter { $0 != .custom }) { sep in
                                Button {
                                    queue.separator = sep
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: sep.icon)
                                            .font(.system(size: 9))
                                        Text(sep.rawValue)
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(queue.separator == sep ? SwiftUI.Color.accentColor.opacity(0.15) : .white.opacity(0.05))
                                    .foregroundStyle(queue.separator == sep ? SwiftUI.Color.accentColor : .secondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)

                        Divider().opacity(0.3)

                        // Action buttons
                        HStack(spacing: 8) {
                            Button {
                                queue.pasteMerged()
                                onDismiss()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.clipboard")
                                        .font(.system(size: 11))
                                    Text("Paste All")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(SwiftUI.Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Button {
                                queue.pasteNext()
                                if !queue.isCollecting {
                                    onDismiss()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.right.circle")
                                        .font(.system(size: 11))
                                    Text("Paste Next")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button {
                                queue.clearQueue()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10))
                                    Text("Clear")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundStyle(.red.opacity(0.8))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.red.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.right.doc.on.clipboard")
                            .font(.system(size: 28, weight: .ultraLight))
                            .foregroundStyle(.quaternary)
                        Text("Items will preview here")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black.opacity(0.03))
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Queue Item Row
struct QueueItemRow: View {
    let item: QueuedClip
    let index: Int
    @ObservedObject private var queue = ClipboardQueueService.shared

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.5))
                .frame(width: 16)

            Image(systemName: "doc.plaintext")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 26, height: 26)
                .background(.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(item.content.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 12))
                    .lineLimit(1)
                Text(item.sourceApp)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 2)

            Button {
                queue.removeItem(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

// MARK: - Clip Row
struct ClipRowView: View {
    let clip: ClipItemViewModel
    let isSelected: Bool
    let rank: Int
    var onDelete: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Rank badge
            Text("\(rank)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary.opacity(0.5))
                .frame(width: 20)

            // Type icon or image thumbnail
            if clip.isImage, let nsImage = ClipSearchPanelView.loadImage(for: clip) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Image(systemName: clip.typeIconName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? .white : clip.typeColor)
                    .frame(width: 26, height: 26)
                    .background(
                        isSelected
                            ? AnyShapeStyle(.white.opacity(0.15))
                            : AnyShapeStyle(clip.typeColor.opacity(0.1))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            // Content
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if clip.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(isSelected ? .white.opacity(0.8) : .orange)
                    }
                    Text(clip.displayTitle)
                        .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)
                }
                if !clip.previewLine.isEmpty && clip.previewLine != clip.displayTitle {
                    Text(clip.previewLine)
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? .white.opacity(0.6) : .secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 2)

            if isHovered {
                Button {
                    onDelete?()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Delete")
                .transition(.opacity)
            } else {
                Text(clip.timeAgo)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.5) : .secondary.opacity(0.4))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            isSelected
                ? AnyShapeStyle(SwiftUI.Color.accentColor.opacity(0.85))
                : AnyShapeStyle(SwiftUI.Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Key-accepting Panel
/// NSPanel subclass that can become key without activating the app.
/// This lets the search panel receive keyboard input while the
/// target app remains the frontmost (active) application.
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Window Controller
class ClipSearchWindowController: NSWindowController, NSWindowDelegate {
    static let shared = ClipSearchWindowController()

    private init() {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
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

    func toggle() {
        if window?.isVisible == true {
            dismiss()
        } else {
            show()
        }
    }

    func show() {
        guard let panel = window else { return }

        // Fresh SwiftUI view each time
        let hostView = NSHostingView(rootView: ClipSearchPanelView(onDismiss: { [weak self] in
            self?.dismiss()
        }))
        hostView.frame = NSRect(x: 0, y: 0, width: 720, height: 520)
        panel.contentView = hostView
        panel.setContentSize(NSSize(width: 720, height: 520))
        // Ensure hosting view layer is transparent after being added to window
        DispatchQueue.main.async {
            hostView.wantsLayer = true
            hostView.layer?.backgroundColor = .clear
            hostView.layer?.isOpaque = false
        }

        // Center on active screen
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            let originX = screenFrame.midX - 360
            let originY = screenFrame.midY - 260 + screenFrame.height * 0.06
            panel.setFrameOrigin(NSPoint(x: originX, y: originY))
        }

        // Don't activate the app — the target app stays frontmost
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func dismiss() {
        window?.orderOut(nil)
        window?.contentView = nil
    }

    /// Dismiss panel then simulate ⌘V.
    /// The panel is non-activating, so the target app is already focused — paste goes right to it.
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
