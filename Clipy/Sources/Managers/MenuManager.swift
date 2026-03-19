//
//  MenuManager.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//
//  Created by Econa77 on 2016/03/08.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa
import RealmSwift
import Combine

final class MenuManager: NSObject {

    // MARK: - Properties
    // Menus
    fileprivate var clipMenu: NSMenu?
    fileprivate var historyMenu: NSMenu?
    fileprivate var snippetMenu: NSMenu?
    // StatusMenu
    fileprivate var statusItem: NSStatusItem?
    // Icon Cache
    fileprivate let folderIcon = Asset.iconFolder.image
    fileprivate let snippetIcon = Asset.iconText.image
    // Other
    fileprivate let notificationCenter = NotificationCenter.default
    fileprivate let kMaxKeyEquivalents = 10
    fileprivate let shortenSymbol = "..."
    // Realm
    fileprivate var realm: Realm?
    fileprivate var clipToken: NotificationToken?
    fileprivate var snippetToken: NotificationToken?
    // Combine
    fileprivate var cancellables = Set<AnyCancellable>()

    // MARK: - Enum Values
    enum StatusType: Int {
        case none, black, white
    }

    // MARK: - Initialize
    override init() {
        super.init()
        folderIcon.isTemplate = true
        folderIcon.size = NSSize(width: 15, height: 13)
        snippetIcon.isTemplate = true
        snippetIcon.size = NSSize(width: 12, height: 13)
        realm = Realm.safeInstance()
    }

    func setup() {
        bind()
    }

}

// MARK: - Popup Menu
extension MenuManager {
    func popUpMenu(_ type: MenuType) {
        let menu: NSMenu?
        switch type {
        case .main:
            menu = clipMenu
        case .history:
            menu = historyMenu
        case .snippet:
            menu = snippetMenu
        }
        menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    func popUpSnippetFolder(_ folder: CPYFolder) {
        let folderMenu = NSMenu(title: folder.title)
        let labelItem = NSMenuItem(title: folder.title, action: nil)
        labelItem.isEnabled = false
        folderMenu.addItem(labelItem)
        var index = firstIndexOfMenuItems()
        folder.snippets
            .sorted(byKeyPath: #keyPath(CPYSnippet.index), ascending: true)
            .filter { $0.enable }
            .forEach { snippet in
                let subMenuItem = makeSnippetMenuItem(snippet, listNumber: index)
                folderMenu.addItem(subMenuItem)
                index += 1
            }
        folderMenu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
}

// MARK: - Binding
private extension MenuManager {
    func bind() {
        guard let realm = realm else { return }

        // Realm Notifications
        clipToken = realm.objects(CPYClip.self)
                        .observe { [weak self] _ in
                            DispatchQueue.main.async { [weak self] in
                                self?.createClipMenu()
                            }
                        }
        snippetToken = realm.objects(CPYFolder.self)
                        .observe { [weak self] _ in
                            DispatchQueue.main.async { [weak self] in
                                self?.createClipMenu()
                            }
                        }

        let defaults = AppEnvironment.current.defaults

        // Status item icon
        defaults.publisher(for: \.clipyShowStatusItem)
            .compactMap { $0 as? Int }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] key in
                self?.changeStatusItem(StatusType(rawValue: key) ?? .black)
            }
            .store(in: &cancellables)

        // Sort clips
        defaults.publisher(for: \.clipyReorderClips)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.createClipMenu()
            }
            .store(in: &cancellables)

        // Edit snippets notification
        notificationCenter
            .publisher(for: Notification.Name(rawValue: Constants.Notification.closeSnippetEditor))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.createClipMenu()
            }
            .store(in: &cancellables)

        // Observe menu preference changes
        let menuPreferenceKeys: [String] = [
            Constants.UserDefaults.addClearHistoryMenuItem,
            Constants.UserDefaults.maxHistorySize,
            Constants.UserDefaults.showIconInTheMenu,
            Constants.UserDefaults.numberOfItemsPlaceInline,
            Constants.UserDefaults.numberOfItemsPlaceInsideFolder,
            Constants.UserDefaults.maxMenuItemTitleLength,
            Constants.UserDefaults.menuItemsTitleStartWithZero,
            Constants.UserDefaults.menuItemsAreMarkedWithNumbers,
            Constants.UserDefaults.showToolTipOnMenuItem,
            Constants.UserDefaults.showImageInTheMenu,
            Constants.UserDefaults.addNumericKeyEquivalents,
            Constants.UserDefaults.maxLengthOfToolTip,
            Constants.UserDefaults.showColorPreviewInTheMenu
        ]

        // Use a single publisher merging all preference key observations
        let publishers = menuPreferenceKeys.map { key in
            NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
                .map { _ in key }
        }

        Publishers.MergeMany(publishers)
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.createClipMenu()
            }
            .store(in: &cancellables)
    }
}

// MARK: - Menus
private extension MenuManager {
     func createClipMenu() {
        clipMenu = NSMenu(title: Constants.Application.name)
        historyMenu = NSMenu(title: Constants.Menu.history)
        snippetMenu = NSMenu(title: Constants.Menu.snippet)

        // Current clipboard indicator
        addCurrentClipboardItem(clipMenu!)

        // Recent clips (just a few for quick access)
        addRecentClips(clipMenu!, maxItems: 5)

        // Search History — the main way to browse
        clipMenu?.addItem(NSMenuItem.separator())
        let searchItem = NSMenuItem(title: "Search History\u{2026}", action: #selector(AppDelegate.showSearchPanel), keyEquivalent: "")
        if let searchImage = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search") {
            searchImage.isTemplate = true
            searchItem.image = searchImage
        }
        clipMenu?.addItem(searchItem)

        // Collect Mode
        let isCollecting = ClipboardQueueService.shared.isCollecting
        if isCollecting {
            let stopItem = NSMenuItem(title: "Stop Collecting (\(ClipboardQueueService.shared.itemCount))", action: #selector(AppDelegate.stopCollectMode), keyEquivalent: "")
            if let stopImage = NSImage(systemSymbolName: "stop.circle", accessibilityDescription: "Stop") {
                stopImage.isTemplate = true
                stopItem.image = stopImage
            }
            clipMenu?.addItem(stopItem)

            if ClipboardQueueService.shared.hasItems {
                let pasteAllItem = NSMenuItem(title: "Paste All (\(ClipboardQueueService.shared.itemCount) items)", action: #selector(AppDelegate.pasteCollectedItems), keyEquivalent: "")
                if let pasteImage = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Paste All") {
                    pasteImage.isTemplate = true
                    pasteAllItem.image = pasteImage
                }
                clipMenu?.addItem(pasteAllItem)
            }
        } else {
            let startItem = NSMenuItem(title: "Start Collect Mode", action: #selector(AppDelegate.startCollectMode), keyEquivalent: "")
            if let startImage = NSImage(systemSymbolName: "tray.and.arrow.down", accessibilityDescription: "Collect") {
                startImage.isTemplate = true
                startItem.image = startImage
            }
            clipMenu?.addItem(startItem)
        }

        // Only add snippet items to the main menu when using classic picker
        let useModernPicker = AppEnvironment.current.defaults.bool(forKey: Constants.Snippets.useModernPicker)
        if !useModernPicker {
            addSnippetItems(clipMenu!, separateMenu: true)
        }
        addSnippetItems(snippetMenu!, separateMenu: false)

        if AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.addClearHistoryMenuItem) {
            let clearItem = NSMenuItem(title: L10n.clearHistory, action: #selector(AppDelegate.clearAllHistory), keyEquivalent: "")
            if let clearImage = NSImage(systemSymbolName: "trash", accessibilityDescription: "Clear") {
                clearImage.isTemplate = true
                clearItem.image = clearImage
            }
            clipMenu?.addItem(clearItem)
        }

        let snippetItem = NSMenuItem(title: L10n.editSnippets, action: #selector(AppDelegate.showSnippetEditorWindow), keyEquivalent: "")
        if let editImage = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Snippets") {
            editImage.isTemplate = true
            snippetItem.image = editImage
        }
        clipMenu?.addItem(snippetItem)

        let prefItem = NSMenuItem(title: L10n.preferences, action: #selector(AppDelegate.showPreferenceWindow), keyEquivalent: ",")
        if let gearImage = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Preferences") {
            gearImage.isTemplate = true
            prefItem.image = gearImage
        }
        clipMenu?.addItem(prefItem)

        clipMenu?.addItem(NSMenuItem.separator())
        clipMenu?.addItem(NSMenuItem(title: L10n.quitClipy, action: #selector(AppDelegate.terminate), keyEquivalent: "q"))

        statusItem?.menu = clipMenu
    }

    func menuItemTitle(_ title: String, listNumber: NSInteger, isMarkWithNumber: Bool) -> String {
        return (isMarkWithNumber) ? "\(listNumber). \(title)" : title
    }

    func makeSubmenuItem(_ count: Int, start: Int, end: Int, numberOfItems: Int) -> NSMenuItem {
        var count = count
        if start == 0 {
            count -= 1
        }
        var lastNumber = count + numberOfItems
        if end < lastNumber {
            lastNumber = end
        }
        let menuItemTitle = "\(count + 1) - \(lastNumber)"
        return makeSubmenuItem(menuItemTitle)
    }

    func makeSubmenuItem(_ title: String) -> NSMenuItem {
        let subMenu = NSMenu(title: "")
        let subMenuItem = NSMenuItem(title: title, action: nil)
        subMenuItem.submenu = subMenu
        subMenuItem.image = (AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showIconInTheMenu)) ? folderIcon : nil
        return subMenuItem
    }

    func incrementListNumber(_ listNumber: NSInteger, max: NSInteger, start: NSInteger) -> NSInteger {
        var listNumber = listNumber + 1
        if listNumber == max && max == 10 && start == 1 {
            listNumber = 0
        }
        return listNumber
    }

    func trimTitle(_ title: String?) -> String {
        if title == nil { return "" }
        let theString = title!.trimmingCharacters(in: .whitespacesAndNewlines) as NSString

        let aRange = NSRange(location: 0, length: 0)
        var lineStart = 0, lineEnd = 0, contentsEnd = 0
        theString.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: aRange)

        var titleString = (lineEnd == theString.length) ? theString as String : theString.substring(to: contentsEnd)

        var maxMenuItemTitleLength = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.maxMenuItemTitleLength)
        if maxMenuItemTitleLength < shortenSymbol.count {
            maxMenuItemTitleLength = shortenSymbol.count
        }

        if titleString.utf16.count > maxMenuItemTitleLength {
            titleString = (titleString as NSString).substring(to: maxMenuItemTitleLength - shortenSymbol.count) + shortenSymbol
        }

        return titleString as String
    }

    func addCurrentClipboardItem(_ menu: NSMenu) {
        let pasteboard = NSPasteboard.general
        var currentTitle = "(Empty clipboard)"
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            currentTitle = trimTitle(trimmed)
            if currentTitle.isEmpty { currentTitle = "(Empty clipboard)" }
        } else if pasteboard.data(forType: .tiff) != nil {
            currentTitle = "(Image)"
        } else if pasteboard.data(forType: .pdf) != nil {
            currentTitle = "(PDF)"
        }

        let headerItem = NSMenuItem(title: "Clipboard: \(currentTitle)", action: nil)
        headerItem.isEnabled = false
        if let clipboardImage = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Current") {
            clipboardImage.isTemplate = true
            headerItem.image = clipboardImage
        }
        menu.addItem(headerItem)

        // Paste as Plain Text action
        let plainTextItem = NSMenuItem(title: "Paste as Plain Text", action: #selector(AppDelegate.pasteAsPlainText), keyEquivalent: "")
        if let textImage = NSImage(systemSymbolName: "textformat", accessibilityDescription: "Plain Text") {
            textImage.isTemplate = true
            plainTextItem.image = textImage
        }
        menu.addItem(plainTextItem)
        menu.addItem(NSMenuItem.separator())
    }
}

// MARK: - Clips
private extension MenuManager {
    func addRecentClips(_ menu: NSMenu, maxItems: Int) {
        guard let realm = realm else { return }

        let ascending = !AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.reorderClipsAfterPasting)
        let clipResults = realm.objects(CPYClip.self).sorted(byKeyPath: #keyPath(CPYClip.updateTime), ascending: ascending)

        guard !clipResults.isEmpty else { return }

        let labelItem = NSMenuItem(title: L10n.history, action: nil)
        labelItem.isEnabled = false
        if let historyImage = NSImage(systemSymbolName: "clock.arrow.trianglehead.counterclockwise.rotate.90", accessibilityDescription: "History") {
            historyImage.isTemplate = true
            labelItem.image = historyImage
        }
        menu.addItem(labelItem)

        let firstIndex = firstIndexOfMenuItems()
        var listNumber = firstIndex
        var count = 0

        for clip in clipResults {
            let menuItem = makeClipMenuItem(clip, index: count, listNumber: listNumber)
            menu.addItem(menuItem)
            listNumber = incrementListNumber(listNumber, max: maxItems, start: firstIndex)
            count += 1
            if count >= maxItems { break }
        }
    }

    func addHistoryItems(_ menu: NSMenu) {
        guard let realm = realm else { return }
        let placeInLine = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.numberOfItemsPlaceInline)
        let placeInsideFolder = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.numberOfItemsPlaceInsideFolder)
        let maxHistory = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.maxHistorySize)

        // History title
        let labelItem = NSMenuItem(title: L10n.history, action: nil)
        labelItem.isEnabled = false
        if let historyImage = NSImage(systemSymbolName: "clock.arrow.trianglehead.counterclockwise.rotate.90", accessibilityDescription: "History") {
            historyImage.isTemplate = true
            labelItem.image = historyImage
        }
        menu.addItem(labelItem)

        // History
        let firstIndex = firstIndexOfMenuItems()
        var listNumber = firstIndex
        var subMenuCount = placeInLine
        var subMenuIndex = 1 + placeInLine

        let ascending = !AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.reorderClipsAfterPasting)
        // Show pinned items first, then sort by time
        let clipResults = realm.objects(CPYClip.self).sorted(by: [
            SortDescriptor(keyPath: #keyPath(CPYClip.isPinned), ascending: false),
            SortDescriptor(keyPath: #keyPath(CPYClip.updateTime), ascending: ascending)
        ])
        let currentSize = Int(clipResults.count)
        var i = 0
        for clip in clipResults {
            if placeInLine < 1 || placeInLine - 1 < i {
                if i == subMenuCount {
                    let subMenuItem = makeSubmenuItem(subMenuCount, start: firstIndex, end: currentSize, numberOfItems: placeInsideFolder)
                    menu.addItem(subMenuItem)
                    listNumber = firstIndex
                }

                if let subMenu = menu.item(at: subMenuIndex)?.submenu {
                    let menuItem = makeClipMenuItem(clip, index: i, listNumber: listNumber)
                    subMenu.addItem(menuItem)
                    listNumber = incrementListNumber(listNumber, max: placeInsideFolder, start: firstIndex)
                }
            } else {
                let menuItem = makeClipMenuItem(clip, index: i, listNumber: listNumber)
                menu.addItem(menuItem)
                listNumber = incrementListNumber(listNumber, max: placeInLine, start: firstIndex)
            }

            i += 1
            if i == subMenuCount + placeInsideFolder {
                subMenuCount += placeInsideFolder
                subMenuIndex += 1
            }

            if maxHistory <= i { break }
        }
    }

    func makeClipMenuItem(_ clip: CPYClip, index: Int, listNumber: Int) -> NSMenuItem {
        let isMarkWithNumber = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.menuItemsAreMarkedWithNumbers)
        let isShowToolTip = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showToolTipOnMenuItem)
        let isShowImage = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showImageInTheMenu)
        let isShowColorCode = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showColorPreviewInTheMenu)
        let addNumbericKeyEquivalents = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.addNumericKeyEquivalents)

        var keyEquivalent = ""

        if addNumbericKeyEquivalents && (index <= kMaxKeyEquivalents) {
            let isStartFromZero = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.menuItemsTitleStartWithZero)

            var shortCutNumber = (isStartFromZero) ? index : index + 1
            if shortCutNumber == kMaxKeyEquivalents {
                shortCutNumber = 0
            }
            keyEquivalent = "\(shortCutNumber)"
        }

        let primaryPboardType = NSPasteboard.PasteboardType(rawValue: clip.primaryType)
        let clipString = clip.title
        let title = trimTitle(clipString)
        var titleWithMark = menuItemTitle(title, listNumber: listNumber, isMarkWithNumber: isMarkWithNumber)

        // Add pin indicator
        if clip.isPinned {
            titleWithMark = "\u{1F4CC} " + titleWithMark
        }

        let menuItem = NSMenuItem(title: titleWithMark, action: #selector(AppDelegate.selectClipMenuItem(_:)), keyEquivalent: keyEquivalent)
        menuItem.representedObject = clip.dataHash

        if isShowToolTip {
            let maxLengthOfToolTip = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.maxLengthOfToolTip)
            let toIndex = (clipString.count < maxLengthOfToolTip) ? clipString.count : maxLengthOfToolTip
            menuItem.toolTip = (clipString as NSString).substring(to: toIndex)
        }

        // Type-specific icons and titles using SF Symbols
        if primaryPboardType.isTIFFType() {
            menuItem.title = menuItemTitle("(Image)", listNumber: listNumber, isMarkWithNumber: isMarkWithNumber)
            if menuItem.image == nil, let img = NSImage(systemSymbolName: "photo", accessibilityDescription: "Image") {
                img.isTemplate = true
                menuItem.image = img
            }
        } else if primaryPboardType.isPDFType() {
            menuItem.title = menuItemTitle("(PDF)", listNumber: listNumber, isMarkWithNumber: isMarkWithNumber)
            if menuItem.image == nil, let img = NSImage(systemSymbolName: "doc.richtext", accessibilityDescription: "PDF") {
                img.isTemplate = true
                menuItem.image = img
            }
        } else if primaryPboardType.isFilenamesType() && title.isEmpty {
            menuItem.title = menuItemTitle("(Filenames)", listNumber: listNumber, isMarkWithNumber: isMarkWithNumber)
            if menuItem.image == nil, let img = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Files") {
                img.isTemplate = true
                menuItem.image = img
            }
        } else if primaryPboardType.isURLType() {
            if menuItem.image == nil, let img = NSImage(systemSymbolName: "link", accessibilityDescription: "URL") {
                img.isTemplate = true
                menuItem.image = img
            }
        }

        if !clip.thumbnailPath.isEmpty && !clip.isColorCode && isShowImage {
            if let cached = ClipService.cachedThumbnail(forKey: clip.thumbnailPath) {
                menuItem.image = cached
            }
        }
        if !clip.thumbnailPath.isEmpty && clip.isColorCode && isShowColorCode {
            if let cached = ClipService.cachedThumbnail(forKey: clip.thumbnailPath) {
                menuItem.image = cached
            }
        }

        return menuItem
    }
}

// MARK: - Snippets
private extension MenuManager {
    func addSnippetItems(_ menu: NSMenu, separateMenu: Bool) {
        guard let realm = realm else { return }
        let folderResults = realm.objects(CPYFolder.self).sorted(byKeyPath: #keyPath(CPYFolder.index), ascending: true)
        guard !folderResults.isEmpty else { return }
        if separateMenu {
            menu.addItem(NSMenuItem.separator())
        }

        let labelItem = NSMenuItem(title: L10n.snippet, action: nil)
        labelItem.isEnabled = false
        menu.addItem(labelItem)

        var subMenuIndex = menu.numberOfItems - 1
        let firstIndex = firstIndexOfMenuItems()

        folderResults
            .filter { $0.enable }
            .forEach { folder in
                let folderTitle = folder.title
                let subMenuItem = makeSubmenuItem(folderTitle)
                menu.addItem(subMenuItem)
                subMenuIndex += 1

                var i = firstIndex
                folder.snippets
                    .sorted(byKeyPath: #keyPath(CPYSnippet.index), ascending: true)
                    .filter { $0.enable }
                    .forEach { snippet in
                        let subMenuItem = makeSnippetMenuItem(snippet, listNumber: i)
                        if let subMenu = menu.item(at: subMenuIndex)?.submenu {
                            subMenu.addItem(subMenuItem)
                            i += 1
                        }
                    }
            }
    }

    func makeSnippetMenuItem(_ snippet: CPYSnippet, listNumber: Int) -> NSMenuItem {
        let isMarkWithNumber = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.menuItemsAreMarkedWithNumbers)
        let isShowIcon = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showIconInTheMenu)

        let title = trimTitle(snippet.title)
        let titleWithMark = menuItemTitle(title, listNumber: listNumber, isMarkWithNumber: isMarkWithNumber)

        let menuItem = NSMenuItem(title: titleWithMark, action: #selector(AppDelegate.selectSnippetMenuItem(_:)), keyEquivalent: "")
        menuItem.representedObject = snippet.identifier
        menuItem.toolTip = snippet.content
        menuItem.image = (isShowIcon) ? snippetIcon : nil

        return menuItem
    }
}

// MARK: - Status Item
private extension MenuManager {
    func changeStatusItem(_ type: StatusType) {
        removeStatusItem()
        if type == .none { return }

        #if DEBUG
        statusItem = NSStatusBar.system.statusItem(withLength: 44)
        if let button = statusItem?.button {
            let image: NSImage?
            switch type {
            case .black:
                image = Asset.statusbarMenuBlack.image
            case .white:
                image = Asset.statusbarMenuWhite.image
            case .none: return
            }
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
            // Add orange "DEV" badge
            let devLabel = NSTextField(labelWithString: "DEV")
            devLabel.font = NSFont.systemFont(ofSize: 7, weight: .bold)
            devLabel.textColor = .orange
            devLabel.sizeToFit()
            devLabel.frame.origin = CGPoint(x: 20, y: 2)
            button.addSubview(devLabel)
            button.toolTip = "Clipy Dev \(Bundle.main.appVersion ?? "") (Debug Build)"
        }
        #else
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            let image: NSImage?
            switch type {
            case .black:
                image = Asset.statusbarMenuBlack.image
            case .white:
                image = Asset.statusbarMenuWhite.image
            case .none: return
            }
            image?.isTemplate = true
            button.image = image
            button.toolTip = "\(Constants.Application.name) \(Bundle.main.appVersion ?? "")"
        }
        #endif
        statusItem?.menu = clipMenu
    }

    func removeStatusItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }
}

// MARK: - Settings
private extension MenuManager {
    func firstIndexOfMenuItems() -> NSInteger {
        return AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.menuItemsTitleStartWithZero) ? 0 : 1
    }
}

// MARK: - UserDefaults KVO Bridge
private extension UserDefaults {
    @objc var clipyShowStatusItem: Any? {
        return object(forKey: Constants.UserDefaults.showStatusItem)
    }
    @objc var clipyReorderClips: Bool {
        return bool(forKey: Constants.UserDefaults.reorderClipsAfterPasting)
    }
}
