# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- **Snippet variables** — `%DATE%`, `%TIME%`, `%CLIPBOARD%`, `%UUID%`, and more — expand at paste time
- **Vault folders** — Touch ID / password-protected snippet folders using LocalAuthentication
- **Clipboard queue (Collect Mode)** — collect multiple clips, paste merged or sequentially
- **Modern preferences window** — SwiftUI settings with General, Shortcuts, Exclude Apps, Updates tabs
- **Pin clips** — keep important clips at the top (`Cmd+P`)
- **Multi-select** — `Shift+Up/Down` to select multiple clips, bulk delete with `Cmd+Backspace`
- **Two-digit quick select** — type two numbers rapidly to select items beyond 9
- **Color code detection** — visual swatch preview for hex colors
- **Clickable URL previews** — blue underlined links open in default browser
- **Window-level shadows** — clean rounded window appearance without border artifacts

### Changed
- Minimum macOS version raised to 14.0 (Sonoma)
- Rebuilt all UI in SwiftUI (search panel, snippet editor, snippet picker, preferences)
- Windows use borderless/titled style with transparent hosting views for clean rounded corners
- Arrow key navigation supports hold-to-repeat in all panels
- Pinned clips preserved when re-copying the same content
- Realm schema migrated to v9 (added `isVault` to CPYFolder, `isPinned` to CPYClip)

### Attribution
This project is a fork of [Clipy/Clipy](https://github.com/Clipy/Clipy) (v1.2.1), originally created by the Clipy Project. See [LICENSE](LICENSE) for details.
