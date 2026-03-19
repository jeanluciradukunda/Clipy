<div align="center">
  <img src="./Resources/clipy_logo.png" width="400">
</div>

<br>

[![CI](https://github.com/jeanluciradukunda/Clipy/actions/workflows/ci.yml/badge.svg)](https://github.com/jeanluciradukunda/Clipy/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/jeanluciradukunda/Clipy)](https://github.com/jeanluciradukunda/Clipy/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-brightgreen)](https://github.com/jeanluciradukunda/Clipy/releases)

**Clipy** is a clipboard manager for macOS — rebuilt with a modern SwiftUI interface, Spotlight-style search, syntax highlighting, OCR, smart actions, and more.

> *Forked from [Clipy/Clipy](https://github.com/Clipy/Clipy) — the original clipboard manager for macOS by [@naotaka](https://github.com/naotaka) and the Clipy Project.*

<!-- TODO: Add demo GIF or video recorded with Screen Studio -->
<!-- <p align="center"><img src="./Resources/demo.gif" width="700"></p> -->

---

## Install

### Download

1. Grab the latest `.dmg` from [**Releases**](https://github.com/jeanluciradukunda/Clipy/releases/latest)
2. Open the DMG and drag Clipy to Applications
3. If macOS shows a security warning, right-click the app → **Open** → **Open Anyway**, or run:
   ```bash
   xattr -cr /Applications/Clipy.app
   ```
   > This is expected — the app is not notarized yet. We're working on Apple Developer ID signing.

### Build from Source

```bash
git clone https://github.com/jeanluciradukunda/Clipy.git && cd Clipy
bundle install --path=vendor/bundle
bundle exec pod install
open Clipy.xcworkspace
# Build (Cmd+B) and Run (Cmd+R) the "Clipy" scheme
```

**Requires**: macOS 14.0 Sonoma+ and Xcode 15.0+

### Uninstall

1. Quit Clipy (click the menu bar icon → Quit, or `Cmd+Q`)
2. Drag Clipy from Applications to Trash
3. Remove app data (optional):
   ```bash
   rm -rf ~/Library/Application\ Support/com.clipy-app.Clipy/
   defaults delete com.clipy-app.Clipy
   ```
4. Remove from System Settings → Privacy & Security → Accessibility

---

## Features

### Search Panel

A Spotlight-style search panel with split-pane layout: filterable clip list on the left, rich preview + action bar on the right.

- **Fuzzy search** across all clipboard history
- **Content filters**: All, Text, Images, Links, Files, Pinned, Queue
- **Keyboard-driven**: arrow keys to navigate, `Return` to paste, `Shift+Return` for plain text
- **Quick select**: type a number to paste instantly — single digits or two digits rapidly (e.g. `1` `5` for item 15, up to 30)
- **Multi-select**: `Shift+Up/Down` to select multiple clips, `Cmd+Backspace` to bulk delete
- **Pin clips** to keep them at the top (`Cmd+P`)

### Syntax Highlighting

Automatic language detection and syntax highlighting for 16+ languages:
JSON, JavaScript, TypeScript, Python, Swift, Java, HTML, CSS, SQL, Shell, Ruby, Go, Rust, C#, C++, YAML

### OCR

Extract text from image clips using the macOS Vision framework. Click **OCR** when previewing an image — extracted text can be copied directly.

### Smart Actions

The action bar adapts to the selected clip's content type:

**Text clips:**
- **UPPER / lower / Title** — case transforms, copied to clipboard
- **Detected content** — clickable badges for URLs (open browser), emails (compose), phone numbers (call), IP addresses (copy)

**JSON clips:**
- **Format** — pretty-print with indentation for readability
- **Minify** — compress to single line for storage/transport

**URL clips:**
- **Clean URL** — strips tracking parameters (UTM, fbclid, gclid, msclkid, and 50+ others)
- **Clickable preview** — blue underlined URL opens in default browser

**Image clips:**
- **OCR** — extract text from the image using macOS Vision framework
- **Share** — native macOS share sheet (AirDrop, Messages, Mail, other apps)

**Color codes:**
- **Visual swatch** — hex color codes show a color preview in the clip list

### Snippet Picker

Spotlight-style snippet browser with folder navigation, search, and keyboard shortcuts. Type a number to quick-paste by position.

### Snippet Editor

Full-featured SwiftUI snippet editor with:
- Sidebar folder/snippet navigation (arrow keys, expand/collapse)
- Inline rename (double-click)
- Variable insertion toolbar
- Import/export as XML

### Snippet Variables

Dynamic variables that expand at paste time:

| Variable | Output |
|---|---|
| `%DATE%` | Current date (yyyy-MM-dd) |
| `%TIME%` | Current time (HH:mm:ss) |
| `%DATETIME%` | Date + time |
| `%DAY%` | Day of the week |
| `%MONTH%` | Current month name |
| `%YEAR%` | Current year |
| `%TIMESTAMP%` | Unix timestamp |
| `%CLIPBOARD%` | Current clipboard text |
| `%UUID%` | Random UUID |
| `%RANDOM%` | Random 4-digit number |

### Vault Folders

Protect sensitive snippets with Touch ID or password authentication. Vault folders stay locked until you authenticate — hidden from search and the snippet picker until unlocked.

### Clipboard Queue (Collect Mode)

Collect multiple clips and paste them all at once — merged with a configurable separator (newline, comma, tab, space) or pasted one-by-one sequentially.

### Other Features

- **Auto-update** — checks GitHub Releases, downloads `.dmg`, installs, and relaunches automatically
- **Color code detection** with visual swatch preview
- **Exclude apps** from clipboard monitoring
- **Hotkey support** for history, snippets, and snippet folders
- **Auto-launch** on system startup
- **Developer Mode** — toggle in Settings → General unlocking TipKit management, database info, hotkey disable toggle, and a vibing Clippy Easter egg
- **TipKit onboarding** — contextual tips in Preferences for feature discovery

---

## Keyboard Shortcuts

All hotkeys (search panel, snippets, snippet folders) are configurable in Settings → Shortcuts.

### Search Panel

| Shortcut | Action |
|---|---|
| `Up/Down` | Navigate clips (hold to repeat) |
| `Shift+Up/Down` | Extend multi-selection |
| `Return` | Paste selected clip |
| `Shift+Return` | Paste as plain text |
| `1`-`30` (type rapidly) | Quick select by number |
| `Cmd+P` | Pin/unpin clip |
| `Cmd+Backspace` | Delete selected clip(s) |
| `Cmd+O` | OCR — extract text from image |
| `Cmd+S` | Share image via system share sheet |
| `Escape` | Close panel |

### Snippet Picker

| Shortcut | Action |
|---|---|
| `Up/Down` | Navigate folders and snippets |
| `Right` | Expand folder / enter snippets |
| `Left` | Collapse folder / go to parent |
| `Return` | Paste selected snippet |
| `1`-`30` (type rapidly) | Quick select snippet by number |
| `Escape` | Close panel |

### Snippet Editor

| Shortcut | Action |
|---|---|
| `Up/Down` | Navigate sidebar (hold to repeat) |
| `Right` | Expand folder / enter snippets |
| `Left` | Collapse folder / go to parent |
| `Cmd+S` | Save current snippet |
| `Escape` | Close editor |

---

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for full setup instructions.

```bash
bundle install --path=vendor/bundle
bundle exec pod install
open Clipy.xcworkspace
```

### Dev Build vs Release

Both can coexist on the same Mac with separate data. To run both simultaneously, enable Developer Mode in the dev build's settings and toggle **"Disable Global Hotkeys"** — this prevents hotkey conflicts.

| | **Clipy** (Release) | **Clipy Dev** (Debug) |
|---|---|---|
| Bundle ID | `com.clipy-app.Clipy` | `com.clipy-app.Clipy-Dev.debug` |
| Data directory | `~/Library/Application Support/com.clipy-app.Clipy/` | `~/Library/Application Support/com.clipy-app.Clipy-Dev.debug/` |
| Menu bar | Standard icon | Icon with orange **DEV** badge |
| Settings title | "Clipy Settings" | "Clipy Dev Settings" |
| Install | DMG from Releases | `Cmd+R` in Xcode |

### Debugging

```bash
log stream --process Clipy --predicate 'subsystem == "com.clipy-app.Clipy"' --level debug
```

### Project Structure

```
Clipy/Sources/
├── Models/          # Realm models (CPYClip, CPYFolder, CPYSnippet)
├── Services/        # ClipService, PasteService, HotKeyService, VaultAuthService
├── Views/
│   ├── SearchPanel/       # Search UI, syntax highlighter, content detection
│   └── SnippetPicker/     # Snippet browser panel
├── Snippets/        # Snippet editor
├── Preferences/     # Settings window
├── Extensions/      # Type helpers, NSImage resize
└── Managers/        # Status bar menu
```

---

## Roadmap

See [Issues](https://github.com/jeanluciradukunda/Clipy/issues) for the full feature roadmap. Look for `good first issue` labels if you'd like to contribute.

---

## Attribution

Clipy is a fork of [Clipy/Clipy](https://github.com/Clipy/Clipy) (v1.2.1), originally created by the [Clipy Project](https://github.com/Clipy). Special thanks to [@naotaka](https://github.com/naotaka) for publishing the original [ClipMenu](https://github.com/naotaka/ClipMenu) as open source.

## License

MIT License. See [LICENSE](LICENSE) for details.

Copyright (c) 2015-2018 Clipy Project
Copyright (c) 2024-2026 Jean Luc Iradukunda
