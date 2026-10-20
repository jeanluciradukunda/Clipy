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

---

## Install

### Download

1. Grab the latest `.dmg` from [**Releases**](https://github.com/jeanluciradukunda/Clipy/releases/latest)
2. Open the DMG and drag Clipy to Applications
3. Launch Clipy — it appears in your menu bar

> Signed and notarized with Apple Developer ID. No Terminal commands or security workarounds needed.

### Build from Source

See [CONTRIBUTING.md](CONTRIBUTING.md). It covers setup and running a Debug build beside the release app without
touching your history.

### Updating

**Auto-update:** Preferences → Updates → Check for Updates, then click **Update Now** and follow the prompts.

**Manual:** Download the latest DMG, drag to Applications (replace existing), and launch.

> Accessibility permission persists across updates — no need to re-grant.

### Uninstall

1. Quit Clipy (click the menu bar icon → Quit, or `Cmd+Q`)
2. Drag Clipy from Applications to Trash
3. Remove your history, snippets and settings (optional):
   ```bash
   rm -rf ~/Library/Application\ Support/com.clipy-app.Clipy ~/Library/Application\ Support/Clipy ~/.clipy
   defaults delete com.clipy-app.Clipy
   ```
   Clipy 2.2.0 and earlier also kept clip files in `~/Library/Application Support/ClipyDev`. Delete that folder too,
   unless you build Clipy Dev from source.
4. Remove Clipy from System Settings → Privacy & Security → Accessibility, and from General → Login Items

---

## Features

- **Search panel** (`Shift+Cmd+V`): fuzzy search across your history, filters (All, Text, Images, Links, Files, Pinned,
  Queue), a preview pane, pinning and multi-select.
- **Syntax highlighting** for 16 languages, with automatic detection.
- **Smart actions** that fit the clip: case changes, JSON format and minify, tracking-free URLs, OCR and Share for
  images, colour swatches, and one-click links for URLs, emails and phone numbers.
- **Snippets**: a picker (`Shift+Cmd+B`), an editor with folders and XML import and export, and variables that expand
  when pasted (below).
- **Vault folders** stay hidden until you unlock them with Touch ID or your password.
- **Collect mode** queues several clips and pastes them together or one by one.
- **Exclude apps** such as password managers from your history.
- **Global hotkeys** for history, snippets and snippet folders, and **launch at login**.
- **Updates** from Settings → Updates.

### Snippet variables

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

---

## Keyboard Shortcuts

Default global hotkeys (configurable in Settings → Shortcuts):

| Shortcut | Action |
|---|---|
| `Shift+Cmd+V` | Open search panel (clipboard history) |
| `Shift+Cmd+B` | Open snippet picker |

### Search Panel

| Shortcut | Action |
|---|---|
| `Up/Down` | Navigate clips (hold to repeat) |
| `Shift+Up/Down` | Extend multi-selection |
| `Tab` | Cycle type filter (All → Text → Images → Links → Files → Pinned → Queue → All) |
| `Return` | Paste selected clip |
| `Shift+Return` | Paste as plain text |
| `1`-`30` (type rapidly) | Quick select by number |
| `Cmd+D` | Pin/unpin clip |
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

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Contributing

Ideas and bugs go in [Issues](https://github.com/jeanluciradukunda/Clipy/issues); `good first issue` marks a place to
start. To build Clipy, see [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Attribution

Clipy is a fork of [Clipy/Clipy](https://github.com/Clipy/Clipy) (v1.2.1), originally created by the [Clipy Project](https://github.com/Clipy). Special thanks to [@naotaka](https://github.com/naotaka) for publishing the original [ClipMenu](https://github.com/naotaka/ClipMenu) as open source.

## Star History

<a href="https://www.star-history.com/?repos=jeanluciradukunda%2FClipy&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=jeanluciradukunda/Clipy&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=jeanluciradukunda/Clipy&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=jeanluciradukunda/Clipy&type=date&legend=top-left" />
 </picture>
</a>

## License

MIT License. See [LICENSE](LICENSE) for details.

Copyright (c) 2015-2018 Clipy Project
Copyright (c) 2024-2026 Jean Luc Iradukunda
