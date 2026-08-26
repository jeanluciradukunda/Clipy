# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Cycle the search panel's type filter from the keyboard** ([#107](https://github.com/jeanluciradukunda/Clipy/issues/107)) — `Tab` advances the active filter chip (All → Text → Images → Links → Files → Pinned → Queue, then back to All) and scrolls it into view, so narrowing by type no longer needs the trackpad. Rebindable in Settings → Shortcuts as "Cycle type filter", alongside the other panel shortcuts.

## [2.2.2] - 2026-07-03

### Fixed
- **In-app update failed with "The file "Clipy" couldn't be saved in the folder "Applications""** — a v2.0.x refactor made the updater swap the app directly from the mounted DMG, but the atomic swap (`replaceItemAt`) must take ownership of the source, which the read-only DMG volume forbids (Cocoa error 512). The new app is now staged in a temporary folder first, and the DMG is detached before the swap so a failure can no longer leave a phantom volume mounted.

## [2.2.1] - 2026-07-02

### Fixed
- **Cross-build data wipe** ([#99](https://github.com/jeanluciradukunda/Clipy/issues/99)) — the Release and Dev builds shared `~/Library/Application Support/ClipyDev/` for clip data files while each kept its own database, so every launch of one build deleted the other build's files as orphans. Pinned image clips kept their history entry but lost the underlying image. Data folders are now separated per build (`Clipy/` for Release, `ClipyDev/` for Dev), and the file cleanup refuses to run when the database reports zero clips, as defence in depth against wiping a folder it does not own.
- **Clear History now erases clip files immediately** — clearing history removed the database records but left the clip data files on disk until a later cleanup pass (a side effect of the new zero-clips safety guard). The files are now deleted at clear time.

### Known limitations
- Clip data files created by v2.2.0 or earlier remain in the old shared `ClipyDev/` folder. The Release build keeps reading them, but running the Dev build can still clean them up as orphans. If you run both builds and want to keep old pinned images, re-copy them once in the Release build so they are stored in the new folder.

## [2.2.0] - 2026-05-09

### Added
- **Script snippets** — new snippet type that runs shell scripts and pastes the output. Configurable shell (`/bin/bash`, `/bin/zsh`, `/bin/sh`, `/usr/bin/python3`), per-snippet timeout, and a Test Run button in the editor.
- **Template gallery** — 14 built-in script templates with parameter forms:
  - **AWS**: SSO Credentials, Secret Fetch (Secrets Manager), Secret Field (JSON key extraction), SSM Parameter
  - **Format**: JSON Pretty Print, JSON Minify
  - **Encode**: Base64 Encode/Decode, URL Encode
  - **Security**: JWT Decode Payload
  - **Convert**: Epoch to Date, Markdown to HTML
  - **Generate**: UUID, Password
- **Plugin system** — drop a folder with `manifest.json` into `~/.clipy/plugins/` to register custom clip processors. Auto-trigger plugins run on every capture, manual ones run on demand. New Plugins tab in Preferences.
- **Ephemeral paste** — script snippet output bypasses clipboard history by default, so secrets do not get saved. Optional auto-clear of the pasteboard after a configurable delay.
- **Path traversal protection** — plugin commands are validated to be relative paths within the plugin directory.

### Fixed
- **History folders not appearing in the menu** ([#88](https://github.com/jeanluciradukunda/Clipy/issues/88)) — the menu was hardcoded to show only 5 clips, ignoring the user's `Items shown inline`, `Items per folder`, and `Max history size` preferences. Replaced with the function that respects those settings, plus fixed an off-by-N indexing bug in submenu lookups.
- **Pinned image / PDF / file clips lost their pin indicator** — the 📌 emoji was overwritten by type-specific titles like `(Image)`. Now applied last so it survives the override.
- **10th menu item displayed as "0." instead of "10."** — inherited ClipMenu behavior wrapped the title number to match the `⌘0` shortcut. The title now shows the real position; the keyboard shortcut still uses `⌘0` (since `⌘10` does not exist on a keyboard).
- **Edit Snippets window had no way to close** ([#90](https://github.com/jeanluciradukunda/Clipy/issues/90)) — added a custom close button in the top-left of the floating panel, matching the app's design language. `⌘W` and `ESC` also work.
- **Script execution pipe deadlock** — long-running scripts producing more than 1 MB of output could hang waiting for the pipe buffer to drain. Now drains fully to EOF, discarding bytes past the limit.
- **Script timeouts could hang** — if a child process ignored `SIGTERM`, the timeout was effectively infinite. Now escalates to `SIGKILL` after a 2 second grace period.
- **`isEphemeral` snippet field not preserved on import/export** — the security toggle for script snippets now round-trips correctly through XML export and import in both the modern and legacy editors.
- **Async plugin loading** — filesystem traversal and JSON decoding moved off the main actor so the Preferences window does not stutter when many plugins are installed.

### Security
- **Plugins disabled by default** on first discovery — auto-trigger plugins now require explicit opt-in to reduce the risk of unintended clipboard exfiltration.
- **Ephemeral paste change-count tracking** — auto-clear now compares `NSPasteboard.changeCount` against the value at write time instead of doing a string match, so the user's real clipboard cannot be wiped if they happen to copy the same string later.

## [2.0.0] - 2026-03-19

### Added
- **Spotlight-style search panel** — split-pane UI with filterable clip list, rich preview, and action bar
- **Syntax highlighting** — automatic language detection for 16+ languages in preview pane
- **OCR** — extract text from image clips using macOS Vision framework
- **Image share button** — native macOS share sheet for image clips (AirDrop, Messages, etc.)
- **Smart clip actions** — contextual buttons based on content type (URL clean, JSON format/minify, text transforms)
- **Content detection** — auto-detects URLs, emails, phone numbers, IP addresses with clickable badges
- **Snippet picker panel** — Spotlight-style snippet browser with folder navigation and search
- **Modern snippets editor** — SwiftUI editor with arrow key navigation, inline rename, import/export
- **Snippet variables** — 10 dynamic variables (`%DATE%`, `%TIME%`, `%MONTH%`, `%YEAR%`, `%TIMESTAMP%`, `%CLIPBOARD%`, `%UUID%`, `%RANDOM%`, and more) that expand at paste time
- **Vault folders** — Touch ID / password-protected snippet folders using LocalAuthentication
- **Clipboard queue (Collect Mode)** — collect multiple clips, paste merged or sequentially
- **Modern preferences window** — SwiftUI settings with General, Shortcuts, Exclude Apps, Updates tabs
- **Pin clips** — keep important clips at the top (`Cmd+P`)
- **Multi-select** — `Shift+Up/Down` to select multiple clips, bulk delete with `Cmd+Backspace`
- **Two-digit quick select** — type two numbers rapidly to select items beyond 9
- **Color code detection** — visual swatch preview for hex colors
- **Clickable URL previews** — blue underlined links open in default browser
- **Window-level shadows** — clean rounded window appearance without border artifacts
- **Auto-update** — downloads `.dmg` from GitHub Releases, installs, and relaunches
- **Developer Mode** — TipKit management, database info, hotkey disable, Clippy Easter egg
- **Dev build cosmetics** — orange DEV badge on menu bar and all panels, separate app name "Clipy Dev"
- **Side-by-side builds** — release and debug can run simultaneously with separate data

### Changed
- Minimum macOS version raised to 14.0 (Sonoma)
- Rebuilt all UI in SwiftUI (search panel, snippet editor, snippet picker, preferences)
- Windows use borderless/titled style with transparent hosting views for clean rounded corners
- Arrow key navigation supports hold-to-repeat in all panels
- Pinned clips preserved when re-copying the same content
- Realm schema migrated to v10 (added `isPinned` and `ocrText` to CPYClip, `isVault` to CPYFolder)

### Attribution
This project is a fork of [Clipy/Clipy](https://github.com/Clipy/Clipy) (v1.2.1), originally created by the Clipy Project. See [LICENSE](LICENSE) for details.
