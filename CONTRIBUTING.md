# Contributing to Clipy

## Set up

You need macOS 14 or later, Xcode 16.2 or later (CI uses 16.2) and [Homebrew](https://brew.sh). You don't need an
Apple Developer account: Debug builds are signed ad hoc.

```bash
brew install cocoapods swiftlint
git clone https://github.com/YOUR_USERNAME/Clipy.git && cd Clipy
pod install
open Clipy.xcworkspace   # the workspace, not the .xcodeproj
```

**If you use Clipy every day, read the next section before your first build.** Then pick the **Clipy** scheme and press
`Cmd+R`. The Debug build is **Clipy Dev**, with an orange DEV badge in the menu bar.

## Run Clipy Dev beside your everyday Clipy

Clipy Dev has its own bundle id, so its history, snippets and settings are separate from the released app's:

| | Clipy (release) | Clipy Dev (Debug) |
|---|---|---|
| Database | `~/Library/Application Support/com.clipy-app.Clipy/` | `~/Library/Application Support/com.clipy-app.Clipy-Dev.debug/` |
| Clip files | `~/Library/Application Support/Clipy/` | `~/Library/Application Support/ClipyDev/` |
| Settings | `defaults read com.clipy-app.Clipy` | `defaults read com.clipy-app.Clipy-Dev.debug` |
| Accessibility | its own entry | its own entry |

A few things are still shared or can reach the other app, so before you start:

1. **Back up** (below). It takes seconds.
2. **Turn Clipy Dev's global hotkeys off**, or both apps fight over `Shift+Cmd+V`: Settings → General → Developer
   Mode, then Developer → Global Hotkeys → Disabled.
3. **Answer "Don't Launch"** if Clipy Dev asks to launch at login. A yes registers your build folder as a login item.
4. **Don't press Update Now in Clipy Dev's Updates tab.** It replaces `/Applications/Clipy.app`.
5. **Don't run the tests locally** (`Cmd+U`) yet. They run inside Clipy Dev and change its real settings and clip
   folder. CI builds every pull request but doesn't run the tests yet, so list the specs you added and a maintainer
   runs them.

Clips saved by Clipy 2.2.0 or earlier keep their files in `ClipyDev/`, and Clipy Dev's clean-up deletes them once Clipy
Dev has its own history. The backup covers them.

Plugins in `~/.clipy/plugins` load in both apps.

### Back up

Quit both apps first, so their databases aren't mid-write:

```bash
B=~/ClipyBackup-$(date +%Y%m%d-%H%M) && mkdir -p "$B" && cd ~/Library/Application\ Support
for d in com.clipy-app.Clipy Clipy com.clipy-app.Clipy-Dev.debug ClipyDev; do [ -d "$d" ] && ditto "$d" "$B/$d"; done
defaults export com.clipy-app.Clipy "$B/com.clipy-app.Clipy.plist"
defaults export com.clipy-app.Clipy-Dev.debug "$B/com.clipy-app.Clipy-Dev.debug.plist"
```

Keep the backup off cloud-synced folders: your clipboard history can hold passwords.

### Restore

This replaces the live folders with the backup's, so anything newer is lost. Quit both apps, set `B` to your backup
folder (for example `B=~/ClipyBackup-20261020-1457`), then:

```bash
A=~/Library/Application\ Support && [ -d "${B:?set B to your backup folder}" ]
for d in com.clipy-app.Clipy Clipy com.clipy-app.Clipy-Dev.debug ClipyDev; do [ -d "$B/$d" ] && rm -rf "$A/$d" && ditto "$B/$d" "$A/$d"; done
defaults import com.clipy-app.Clipy "$B/com.clipy-app.Clipy.plist"
defaults import com.clipy-app.Clipy-Dev.debug "$B/com.clipy-app.Clipy-Dev.debug.plist"
```

### If paste stops working after a rebuild

Clipy Dev needs Accessibility permission to paste. If paste stops after a rebuild, reset its entry and grant it again
when asked:

```bash
tccutil reset Accessibility com.clipy-app.Clipy-Dev.debug
```

## Pull requests

- Branch from `main`. One fix or feature per PR, with a test where you can.
- SwiftLint runs on every build. Fix its warnings in the lines you touch.
- Open the PR against `main` and say what changed and why. CI on a fork's first PR waits for a maintainer's approval.

Bug reports: macOS version, steps, expected and actual result. Logs help:

```bash
log stream --predicate 'subsystem == "com.clipy-app.Clipy"' --level debug
```

## Code

- SwiftUI for new UI; AppKit only where the system needs it.
- `@MainActor` for view models and services that touch UI.
- `Logger` with subsystem `com.clipy-app.Clipy`.
- Strings live in `Clipy/Resources/<lang>.lproj/Localizable.strings`. SwiftGen regenerates `Clipy/Generated/` on
  every build.

By contributing, you agree to license your work under the [MIT License](LICENSE).
