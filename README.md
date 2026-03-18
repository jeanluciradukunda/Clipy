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

Grab the latest `.dmg` from [**Releases**](https://github.com/jeanluciradukunda/Clipy/releases/latest), open it, and drag Clipy to Applications.

### Build from Source

```bash
git clone https://github.com/jeanluciradukunda/Clipy.git && cd Clipy
bundle install --path=vendor/bundle
bundle exec pod install
open Clipy.xcworkspace
# Build (Cmd+B) and Run (Cmd+R) the "Clipy" scheme
```

**Requires**: macOS 14.0 Sonoma+ and Xcode 15.0+

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

Contextual buttons based on clip content:

- **Text transforms**: UPPER, lower, Title case
- **JSON**: Format (pretty-print) and Minify
- **URL cleaning**: strips tracking parameters (UTM, fbclid, gclid, and 50+ others)
- **Content detection**: clickable badges for URLs, emails, phone numbers, IP addresses
- **Image sharing**: native macOS share sheet (AirDrop, Messages, Mail)

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

- **Color code detection** with visual swatch preview
- **Exclude apps** from clipboard monitoring
- **Hotkey support** for history, snippets, and snippet folders
- **Auto-launch** on system startup
- **Auto-update** via Sparkle

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

### Debugging

```bash
log stream --process Clipy --predicate 'subsystem == "com.clipy-app.Clipy-Dev"' --level debug
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

See [wishlist.md](wishlist.md) for the full feature roadmap and progress.

---

## Attribution

Clipy is a fork of [Clipy/Clipy](https://github.com/Clipy/Clipy) (v1.2.1), originally created by the [Clipy Project](https://github.com/Clipy). Special thanks to [@naotaka](https://github.com/naotaka) for publishing the original [ClipMenu](https://github.com/naotaka/ClipMenu) as open source.

## License

MIT License. See [LICENSE](LICENSE) for details.

Copyright (c) 2015-2018 Clipy Project
Copyright (c) 2024-2026 Jean Luc Iradukunda
