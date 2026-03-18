# Contributing to Clipy

Thanks for your interest in contributing! This guide will help you get started.

## Getting Started

### Prerequisites

| Tool | Version | Notes |
|---|---|---|
| **macOS** | 14.0+ | Sonoma or later |
| **Xcode** | 15.0+ | From the Mac App Store |
| **Ruby** | 2.7+ | Ships with macOS, or use `rbenv` |
| **Bundler** | — | `gem install bundler` |

### Setup

```bash
# Fork and clone
git clone https://github.com/YOUR_USERNAME/Clipy.git
cd Clipy

# Install dependencies
bundle install --path=vendor/bundle
bundle exec pod install

# Open in Xcode
open Clipy.xcworkspace
```

> Always open `Clipy.xcworkspace`, not `Clipy.xcodeproj`.

### Build & Run

1. Select the **Clipy** scheme in Xcode
2. `Cmd+B` to build, `Cmd+R` to run
3. The app appears in your menu bar

## How to Contribute

### Reporting Bugs

Open an issue with:
- macOS version
- Steps to reproduce
- Expected vs actual behavior
- Console logs if relevant (`log stream --process Clipy --predicate 'subsystem == "com.clipy-app.Clipy-Dev"' --level debug`)

### Suggesting Features

Check the [wishlist](wishlist.md) first — your idea might already be tracked. If not, open an issue describing:
- The problem you're trying to solve
- Your proposed solution
- Any alternatives you've considered

### Pull Requests

1. **Fork** the repo and create a branch from `main`
2. **Name your branch** descriptively: `feature/clipboard-diff`, `fix/pin-state-lost`, etc.
3. **Keep PRs focused** — one feature or fix per PR
4. **Test your changes** — build and run the app, verify the feature works
5. **Follow the code style** — SwiftLint runs as a build phase; fix any warnings
6. Open a PR against `main` with a clear description of what and why

### Code Style

- SwiftUI for all new UI (no new AppKit views unless necessary for system integration)
- `@MainActor` for all view models and services that touch UI
- Use `os.log` / `Logger` for debug logging (subsystem: `com.clipy-app.Clipy-Dev`)
- Keep files under 500 lines where practical (SwiftLint warns at 500)

### Project Structure

```
Clipy/Sources/
├── Models/          # Realm models
├── Services/        # Core services (ClipService, PasteService, etc.)
├── Views/           # SwiftUI panels (SearchPanel, SnippetPicker)
├── Snippets/        # Snippet editor
├── Preferences/     # Settings window
├── Extensions/      # Type helpers and utilities
└── Managers/        # Menu bar management
```

### Localization

Clipy supports multiple languages. To add or update translations:

1. Find the `.lproj` directories in `Clipy/Resources/`
2. Edit `Localizable.strings` for your language
3. Run `bundle exec pod install` to regenerate SwiftGen constants

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
