<div align="center">
  <img src="./Resources/clipy_logo.png" width="400">
</div>

<br>

![CI](https://github.com/Clipy/Clipy/workflows/CI/badge.svg)
[![Release version](https://img.shields.io/github/release/Clipy/Clipy.svg)](https://github.com/Clipy/Clipy/releases/latest)
[![OpenCollective](https://opencollective.com/clipy/backers/badge.svg)](#backers)
[![OpenCollective](https://opencollective.com/clipy/sponsors/badge.svg)](#sponsors)

Clipy is a Clipboard extension app for macOS — modernized with a Spotlight/Raycast-style search panel, syntax highlighting, OCR, smart clip actions, and more.

---

__Requirement__: macOS 14.0 Sonoma or higher

__Distribution Site__ : <https://clipy-app.com>

<img src="http://clipy-app.com/img/screenshot1.png" width="400">

## Features

### Search Panel
A Spotlight-style search panel (triggered via hotkey) with split-pane layout: a filterable clip list on the left, a rich preview + action bar on the right.

- **Fuzzy search** across all clipboard history
- **Content filters**: All, Text, Images, Links, Files, Pinned, Queue
- **Keyboard-driven**: arrow keys to navigate, `Return` to paste, `Shift+Return` for plain text, `1-9` for quick paste
- **Multi-select**: `Shift+Up/Down` to select multiple clips, `Cmd+Backspace` to bulk delete
- **Hover-to-delete**: red minus button appears on hover for quick removal

### Syntax Highlighting
Automatic language detection and syntax highlighting for 16+ languages in the preview pane:
JSON, JavaScript, TypeScript, Python, Swift, Java, HTML, CSS, SQL, Shell, Ruby, Go, Rust, C#, C++, YAML

### OCR (Optical Character Recognition)
Extract text from image clips using the macOS Vision framework. Click the **OCR** button in the action bar when previewing an image — extracted text can be copied directly.

### Smart Clip Actions
The action bar shows contextual buttons based on clip content:

- **Text transforms**: UPPER, lower, Title case
- **JSON**: Format (pretty-print) and Minify buttons for valid JSON
- **Link sanitization**: "Clean URL" strips tracking parameters (UTM, fbclid, gclid, msclkid, and 50+ others)
- **Actionable content detection**: Automatically detects URLs, email addresses, IP addresses, and phone numbers — shows Open, Mail, Copy IP, or Call buttons accordingly

### Snippet Variables
Dynamic variables in snippets that expand at paste time:

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

The snippet editor includes a **Variables** button that shows all available variables and lets you insert them with one click.

### Clipboard Queue (Collect Mode)
Collect multiple clips and paste them all at once — merged with a configurable separator (newline, comma, tab, space) or pasted one-by-one sequentially.

### Other Features
- **Pin clips** to keep them at the top (`Cmd+P`)
- **Image preview** with thumbnail in the clip list and full-size in the preview pane
- **Color code detection** with visual swatch preview
- **Exclude apps** from clipboard monitoring
- **Hotkey support** for history, snippets, and snippet folders
- **Auto-launch** on system startup via Login Items

## Development

### Prerequisites

| Tool | Version | Notes |
|---|---|---|
| **macOS** | 14.0+ | Sonoma or later |
| **Xcode** | 15.0+ | Install from the Mac App Store |
| **Xcode Command Line Tools** | — | `xcode-select --install` |
| **Ruby** | 2.7+ | Ships with macOS, or use `rbenv`/`rvm` |
| **Bundler** | — | `gem install bundler` |
| **CocoaPods** | 1.14+ | Installed via Bundler (see build steps) |

### How to Build

```bash
# 1. Clone the repo
git clone https://github.com/Clipy/Clipy.git && cd Clipy

# 2. Install Ruby gems and CocoaPods dependencies
bundle install --path=vendor/bundle
bundle exec pod install

# 3. Open the workspace in Xcode
open Clipy.xcworkspace

# 4. Build (Cmd+B) and Run (Cmd+R) the "Clipy" scheme
```

> **Important**: Always open `Clipy.xcworkspace` (not `Clipy.xcodeproj`) — the workspace includes CocoaPods dependencies.

### Running a Debug Build from Terminal

After building in Xcode, you can launch the debug build directly:

```bash
open ~/Library/Developer/Xcode/DerivedData/Clipy-*/Build/Products/Debug/Clipy.app
```

If you get a launch error (error 163 — invalid code signature after rebuild):

```bash
codesign --force --deep --sign - ~/Library/Developer/Xcode/DerivedData/Clipy-*/Build/Products/Debug/Clipy.app
```

### Debugging with os.log

Clipy uses Apple's unified logging system (`os.log`) with the subsystem `com.clipy-app.Clipy-Dev`.

**Stream logs in real-time** (run this in Terminal, then use the app):

```bash
log stream --process Clipy --predicate 'subsystem == "com.clipy-app.Clipy-Dev"' --level debug
```

**View recent logs** (after the fact):

```bash
log show --last 5m --predicate 'subsystem == "com.clipy-app.Clipy-Dev"' --level debug
```

**Filter by category** (e.g. only ClipService logs):

```bash
log stream --process Clipy \
  --predicate 'subsystem == "com.clipy-app.Clipy-Dev" AND category == "ClipService"' \
  --level debug
```

> **Tip**: By default macOS redacts dynamic values in debug logs. Use `privacy: .public` in log interpolations during development to see actual values:
> ```swift
> logger.debug("Value: \(someVar, privacy: .public)")
> ```

### Adding Debug Logging

```swift
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy-Dev", category: "YourCategory")

// Usage
logger.debug("Something happened: \(value, privacy: .public)")
logger.info("Clip saved successfully")
logger.error("Failed to save: \(error.localizedDescription, privacy: .public)")
```

### Project Structure

```
Clipy/Sources/
├── Models/              # Realm models (CPYClip, CPYClipData, CPYSnippet, CPYFolder)
├── Services/            # Core services
│   ├── ClipService        # Clipboard monitoring, saving, thumbnail caching
│   ├── PasteService       # Pasteboard operations, simulated Cmd+V
│   ├── HotKeyService      # Global hotkey registration
│   ├── ExcludeAppService  # App exclusion from monitoring
│   └── ClipboardQueueService # Collect mode / queue
├── Managers/
│   └── MenuManager        # Status bar menu construction
├── Views/
│   └── SearchPanel/
│       ├── ClipSearchPanel      # Main search UI, ViewModel, row views
│       ├── SyntaxHighlighter    # Language detection + regex syntax coloring
│       └── ClipIntelligence     # OCR, link sanitization, content detection, snippet variables
├── Snippets/
│   └── ModernSnippetsEditor     # SwiftUI snippet editor with variable support
├── Preferences/
│   └── ModernPreferencesWindow  # SwiftUI settings window
├── Extensions/          # NSPasteboard type helpers, NSImage resize, etc.
└── Utility/             # UserDefaults registration, file utilities
```

### Key Architecture Decisions

- **Realm** for clip/snippet persistence — lightweight embedded database
- **NSCache** for thumbnail images — in-memory only, rebuilt from `.data` files on cache miss
- **`@MainActor` pasteboard polling** at 500ms intervals — reliable clipboard change detection
- **SwiftUI** for the search panel, preferences, and snippet editor — hosted in `NSPanel`/`NSWindow` via `NSHostingView`
- **CGEvent** for simulated paste — requires Accessibility permission

### SwiftLint

The project uses SwiftLint (run as a build phase). Configuration is in `.swiftlint.yml`:

- `line_length`: 300
- `file_length`: warning at 500, error at 1000
- `identifier_name`: minimum 3 characters (excludes `i`)

### Contributing
1. Fork it ( https://github.com/Clipy/Clipy/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

### Localization Contributors
Clipy is looking for localization contributors.
If you can contribute, please see [CONTRIBUTING.md](https://github.com/Clipy/Clipy/blob/master/.github/CONTRIBUTING.md)

### Distribution
If you distribute derived work, especially in the Mac App Store, I ask you to follow two rules:

1. Don't use `Clipy` and `ClipMenu` as your product name.
2. Follow the MIT license terms.

Thank you for your cooperation.

### Backers

Support us with a monthly donation and help us continue our activities. [[Become a backer](https://opencollective.com/clipy#backer)]

<a href="https://opencollective.com/clipy/backer/0/website" target="_blank"><img src="https://opencollective.com/clipy/backer/0/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/1/website" target="_blank"><img src="https://opencollective.com/clipy/backer/1/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/2/website" target="_blank"><img src="https://opencollective.com/clipy/backer/2/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/3/website" target="_blank"><img src="https://opencollective.com/clipy/backer/3/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/4/website" target="_blank"><img src="https://opencollective.com/clipy/backer/4/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/5/website" target="_blank"><img src="https://opencollective.com/clipy/backer/5/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/6/website" target="_blank"><img src="https://opencollective.com/clipy/backer/6/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/7/website" target="_blank"><img src="https://opencollective.com/clipy/backer/7/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/8/website" target="_blank"><img src="https://opencollective.com/clipy/backer/8/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/9/website" target="_blank"><img src="https://opencollective.com/clipy/backer/9/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/10/website" target="_blank"><img src="https://opencollective.com/clipy/backer/10/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/11/website" target="_blank"><img src="https://opencollective.com/clipy/backer/11/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/12/website" target="_blank"><img src="https://opencollective.com/clipy/backer/12/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/13/website" target="_blank"><img src="https://opencollective.com/clipy/backer/13/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/14/website" target="_blank"><img src="https://opencollective.com/clipy/backer/14/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/15/website" target="_blank"><img src="https://opencollective.com/clipy/backer/15/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/16/website" target="_blank"><img src="https://opencollective.com/clipy/backer/16/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/17/website" target="_blank"><img src="https://opencollective.com/clipy/backer/17/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/18/website" target="_blank"><img src="https://opencollective.com/clipy/backer/18/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/19/website" target="_blank"><img src="https://opencollective.com/clipy/backer/19/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/20/website" target="_blank"><img src="https://opencollective.com/clipy/backer/20/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/21/website" target="_blank"><img src="https://opencollective.com/clipy/backer/21/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/22/website" target="_blank"><img src="https://opencollective.com/clipy/backer/22/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/23/website" target="_blank"><img src="https://opencollective.com/clipy/backer/23/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/24/website" target="_blank"><img src="https://opencollective.com/clipy/backer/24/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/25/website" target="_blank"><img src="https://opencollective.com/clipy/backer/25/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/26/website" target="_blank"><img src="https://opencollective.com/clipy/backer/26/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/27/website" target="_blank"><img src="https://opencollective.com/clipy/backer/27/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/28/website" target="_blank"><img src="https://opencollective.com/clipy/backer/28/avatar.svg"></a>
<a href="https://opencollective.com/clipy/backer/29/website" target="_blank"><img src="https://opencollective.com/clipy/backer/29/avatar.svg"></a>

### Sponsors

Become a sponsor and get your logo on our README on Github with a link to your site. [[Become a sponsor](https://opencollective.com/clipy#sponsor)]

<a href="https://opencollective.com/clipy/sponsor/0/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/0/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/1/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/1/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/2/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/2/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/3/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/3/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/4/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/4/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/5/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/5/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/6/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/6/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/7/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/7/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/8/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/8/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/9/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/9/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/10/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/10/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/11/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/11/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/12/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/12/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/13/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/13/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/14/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/14/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/15/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/15/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/16/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/16/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/17/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/17/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/18/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/18/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/19/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/19/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/20/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/20/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/21/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/21/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/22/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/22/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/23/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/23/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/24/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/24/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/25/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/25/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/26/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/26/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/27/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/27/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/28/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/28/avatar.svg"></a>
<a href="https://opencollective.com/clipy/sponsor/29/website" target="_blank"><img src="https://opencollective.com/clipy/sponsor/29/avatar.svg"></a>

### Licence
Clipy is available under the MIT license. See the LICENSE file for more info.

Icons are copyrighted by their respective authors.

### Special Thanks
__Thank you for [@naotaka](https://github.com/naotaka) who have published [ClipMenu](https://github.com/naotaka/ClipMenu) as OSS.__
