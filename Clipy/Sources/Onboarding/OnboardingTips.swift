//
//  OnboardingTips.swift
//
//  Clipy
//
//  TipKit onboarding tips for contextual feature discovery.
//

import SwiftUI
import TipKit

// MARK: - Search Panel Tips

struct QuickSelectTip: Tip {
    var title: Text { Text("Quick Select") }
    var message: Text? { Text("Type a number to instantly paste a clip. For two-digit items like 15, type both digits rapidly.") }
    var image: Image? { Image(systemName: "keyboard") }
}

struct FiltersTip: Tip {
    var title: Text { Text("Filter Your Clips") }
    var message: Text? { Text("Use filters to show only Text, Images, Links, Files, Pinned, or Queue items.") }
    var image: Image? { Image(systemName: "line.3.horizontal.decrease.circle") }
}

struct PinClipTip: Tip {
    var title: Text { Text("Pin Important Clips") }
    var message: Text? { Text("Press \u{2318}P to pin a clip so it stays at the top of your history.") }
    var image: Image? { Image(systemName: "pin") }
}

struct MultiSelectTip: Tip {
    var title: Text { Text("Select Multiple Clips") }
    var message: Text? { Text("Hold Shift + Up/Down to select multiple clips. Delete them all with \u{2318}\u{232B}.") }
    var image: Image? { Image(systemName: "checkmark.circle") }
}

struct PlainTextTip: Tip {
    var title: Text { Text("Paste as Plain Text") }
    var message: Text? { Text("Press Shift+Return to paste without formatting — strips fonts, colors, and styles.") }
    var image: Image? { Image(systemName: "textformat") }
}

// MARK: - Image Tips

struct OCRTip: Tip {
    var title: Text { Text("Extract Text from Images") }
    var message: Text? { Text("Click OCR to read text from any image clip using macOS Vision.") }
    var image: Image? { Image(systemName: "text.viewfinder") }
}

struct ShareImageTip: Tip {
    var title: Text { Text("Share Images") }
    var message: Text? { Text("Send image clips to other apps via AirDrop, Messages, Mail, and more.") }
    var image: Image? { Image(systemName: "square.and.arrow.up") }
}

// MARK: - Smart Action Tips

struct URLCleanTip: Tip {
    var title: Text { Text("Clean Tracking URLs") }
    var message: Text? { Text("Strips UTM, fbclid, gclid, and 50+ tracking parameters from URLs.") }
    var image: Image? { Image(systemName: "link.badge.plus") }
}

struct JSONFormatTip: Tip {
    var title: Text { Text("Format or Minify JSON") }
    var message: Text? { Text("Pretty-print JSON for readability, or minify it for compact storage.") }
    var image: Image? { Image(systemName: "curlybraces") }
}

// MARK: - Snippet Tips

struct SnippetNavigationTip: Tip {
    var title: Text { Text("Navigate with Arrow Keys") }
    var message: Text? { Text("Use \u{2191}\u{2193} to browse, \u{2192} to expand a folder, \u{2190} to collapse. Press Return to paste.") }
    var image: Image? { Image(systemName: "arrow.up.arrow.down") }
}

struct SnippetVariablesTip: Tip {
    var title: Text { Text("Dynamic Variables") }
    var message: Text? { Text("Insert variables like %DATE%, %TIME%, %CLIPBOARD% that auto-fill when you paste.") }
    var image: Image? { Image(systemName: "percent") }
}

struct VaultFolderTip: Tip {
    var title: Text { Text("Protect with Touch ID") }
    var message: Text? { Text("Right-click a folder and choose \"Set as Vault\" to require Touch ID before viewing its snippets.") }
    var image: Image? { Image(systemName: "lock.shield") }
}

// MARK: - Collect Mode Tips

struct CollectModeTip: Tip {
    var title: Text { Text("Clipboard Queue") }
    var message: Text? { Text("Switch to Queue mode to collect multiple clips, then paste them all at once with a separator.") }
    var image: Image? { Image(systemName: "tray.and.arrow.down") }
}

// MARK: - Settings Tips

struct CustomizeShortcutsTip: Tip {
    var title: Text { Text("Customize Shortcuts") }
    var message: Text? { Text("Click to record a new shortcut. You can change hotkeys for the search panel, snippets, and more.") }
    var image: Image? { Image(systemName: "command") }
}

struct HistorySizeTip: Tip {
    var title: Text { Text("Adjust History Size") }
    var message: Text? { Text("Set how many clips to keep. Higher values use more storage but give you a longer history.") }
    var image: Image? { Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90") }
}
