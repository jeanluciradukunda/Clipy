# Clipy Dev — Feature Wishlist

Track upcoming features. Mark `[x]` when complete.

---

## Memory & ARC (Critical)
- [ ] **Fix retain cycles in VaultAuthService auth callbacks** — `SnippetPickerPanel` and `ModernSnippetsEditor` capture view state without `[weak self]` in `VaultAuthService.shared.authenticate` completion closures. If user dismisses during biometric auth, entire SwiftUI view hierarchy stays retained by LAContext callback
- [ ] **Stop recreating NSHostingView on every show()** — `SnippetPickerWindowController.show()` and `ModernSnippetsWindowController.showWindow()` create a new NSHostingView each call, leaking old Combine subscriptions and @StateObject view models. Reuse existing hosting view or properly tear down old one
- [ ] **Fix Realm cross-instance object access** — `ClipService.save()` creates a CPYClip on one Realm instance then adds it to a different instance inside `DispatchQueue.main.async`. Realm objects are instance-specific — risks invalidation errors and data corruption
- [ ] **Cache clip data for search filtering** — `ClipSearchPanel` deserializes every clip from disk via `NSKeyedUnarchiver` during search (N+1). With 1000 clips this causes 100MB+ memory spikes on main thread. Add an in-memory searchable text cache
- [ ] **Materialize Realm Results before iteration** — `SnippetPickerPanel` and `ModernSnippetsEditor` iterate live `Results<CPYFolder>` without converting to `Array`. If Realm state changes mid-iteration, invalidation crash
- [ ] **Fix Task cancellation race in ClipboardQueueService** — polling Task sleeps 200ms between cancellation checks, so clipboard monitoring continues ~200ms after `cancel()`. Check `Task.isCancelled` after sleep
- [ ] **Cache `timeAgo` computed property** — recalculated for every clip on every render (500+ calls per view update including off-screen clips). Cache with periodic refresh
- [ ] **Set thumbnail cache size limit** — `ClipService.thumbnailCache` NSCache has no `totalCostLimit`, can grow unbounded with large image histories
- [ ] **Cancel Combine subscription in CollectModeIndicator** — `$isCollecting` subscription is never explicitly cancelled, leaks subscription object
- [ ] **Fix KVO on computed UserDefaults properties** — `UserDefaults.publisher(for:)` on computed extension properties won't emit changes. Affects login item, status item, store types observers. Use `UserDefaults.didChangeNotification` instead
- [ ] **Regenerate menu thumbnails on cache miss** — after relaunch NSCache is empty, menu items show no thumbnails. Load from `.data` file on miss and re-cache

## Security Hardening
- [ ] **Encrypt .data files on disk** — NSKeyedArchiver clip data files in `~/Library/Application Support/Clipy/` are unencrypted. Encrypt with CryptoKit AES-GCM using the same Keychain key as Realm
- [ ] **Auto-clear pasteboard after paste** — content stays on system clipboard indefinitely after pasting. Add configurable auto-clear timer (e.g. 30s after paste)
- [ ] **Clear clip data from memory on panel dismiss** — sensitive clip content in ViewModels persists in memory until garbage collection

## Privacy & Security
- [ ] **Auto-expiring clips** — detect copies from password managers (1Password, Bitwarden) or banking apps and auto-delete after 30s. Use existing exclude app detection to identify source apps and apply per-app TTL rules
- [ ] **Incognito mode** — hotkey-activated toggle that pauses clipboard recording. Status bar icon changes to indicate paused state. Useful during screen sharing or handling sensitive data
- [ ] **Sensitive content masking** — auto-detect patterns like API keys, credit card numbers, SSNs in clip previews and blur/redact them in the menu UI. Actual content still pasteable, just visually masked
- [ ] **Per-app retention rules** — beyond excluding apps, set rules like "keep clips from Terminal for 1 hour" or "never store images from Safari"

## Clipboard Intelligence
- [ ] **Type-aware quick actions** — detect clip content type (URL, email, hex color, JSON, phone number, file path) and surface contextual actions. E.g., URL → "Open in Browser", color → show swatch + "Copy as RGB/HSL", JSON → "Pretty Print", file path → "Reveal in Finder"
- [x] **Image OCR** — extract text from image clips using Vision framework. Show extracted text as searchable subtitle, offer "Copy Text from Image" action
- [x] **Image share button** — add a share icon on image clips that triggers the macOS system share sheet (AirDrop, Messages, Mail, other apps)
- [ ] **URL rich preview** — for URL clips, async-fetch page title and favicon, display in menu instead of raw URLs
- [ ] **Smart deduplication** — detect near-duplicates (same text with trailing whitespace, same URL with different tracking params) and offer to merge

## Productivity
- [ ] **Text transforms** — submenu or keyboard shortcut on any text clip: uppercase, lowercase, title case, trim whitespace, URL encode/decode, base64, JSON pretty-print, markdown → plain text, sort lines, remove duplicates
- [ ] **Clip merging** — select multiple clips (checkboxes or shift-click in search panel) and combine with configurable separator (newline, comma, space)
- [ ] **Clipboard chains** — define a sequence of clips that paste one after another. Each Cmd+V advances to the next item. Useful for filling forms
- [ ] **Quick templates** — like snippets but triggered from clipboard menu with fill-in placeholders that pop up an inline form before pasting

## UI / UX
- [ ] **Drag and drop** — allow dragging clips from search panel directly into target apps
- [ ] **Timeline grouping** — group clips by time (Today / Yesterday / This Week / Older) or by source app, with collapsible section headers
- [ ] **Mini floating widget** — small always-on-top strip (Touch Bar style) showing last 3-5 clips as tiny previews. Click to paste. Dismissable, repositionable
- [ ] **Clip statistics dashboard** — preferences tab showing daily clip count, most-copied content, breakdown by type (text/image/file), storage usage
- [ ] **Accent color / theme picker** — let users pick accent color for the liquid glass UI, or offer preset themes

## Power User
- [ ] **Regex clip rules** — define rules like "if clip matches API key pattern, auto-delete after 60s" or "if clip matches email, auto-tag as 'email'"
- [ ] **Clipboard diff** — select two clips and see side-by-side diff highlighting changes
- [ ] **AppleScript / Shortcuts.app integration** — expose actions like "Get last clip", "Search clips", "Paste snippet by name" as Shortcuts actions
- [ ] **URL scheme** — `clipy://paste?snippet=My+Snippet` or `clipy://search?q=hello` for Alfred/Raycast/script integration
- [ ] **Export/sync** — iCloud sync for snippet folders across Macs. Export clipboard history as JSON/CSV

## Code Health
- [ ] **Shared floating panel controller** — `ClipSearchWindowController` and `SnippetPickerWindowController` are near-identical singletons (KeyablePanel setup, toggle/show/dismiss/dismissAndPaste). Extract a generic base class parameterized by content view and size
- [ ] **Move `KeyablePanel` to shared location** — currently defined in ClipSearchPanel.swift but used by SnippetPickerPanel.swift, creating a hidden cross-file dependency
- [ ] **SnippetFolderRow delegate pattern** — replace 12 individual closure parameters with a delegate protocol or action enum to reduce parameter sprawl
- [ ] **Deduplicate `isVaultUnlocked` state** — `SnippetFolderRow.isVaultUnlocked` shadows `VaultAuthService.shared.isUnlocked()`, creating two sources of truth. Make VaultAuthService observable and query it directly
- [ ] **Shared `PasteboardMonitor`** — `ClipService` and `ClipboardQueueService` both implement identical pasteboard polling loops. Extract to a shared utility
- [ ] **Shared snippet import/export utility** — `ModernSnippetsEditor` and `CPYSnippetsEditorWindowController` duplicate the same AEXML XML import/export logic
- [ ] **Use `PasteService.copyToPasteboard` consistently** — `AppDelegate.pasteAsPlainText()` and `ClipSearchViewModel.pasteAsPlainText()` manually clear/set pasteboard instead of using the existing helper
- [ ] **Logger subsystem constant** — `"com.clipy-app.Clipy-Dev"` hardcoded in 13 files; extract to `Constants.Application.logSubsystem`
- [ ] **PanelShortcutService enum IDs** — `save()` dispatches on raw string IDs ("pin", "delete", etc.); replace with a proper enum for compile-time safety
- [ ] **Async image loading in clip rows** — `ClipRowView.body` synchronously loads images from disk on cache miss; use `.task {}` for async loading during scroll
- [ ] **Lazy clip text loading** — `loadClips()` unarchives every clip from disk for searchable text (N+1 pattern); defer to background or load lazily
- [ ] **Cache `SyntaxHighlighter` instance** — new instance allocated on every preview render; use a shared/static instance
- [ ] **Debounce snippet sidebar filter** — `filteredFolders` fires on every keystroke with no debounce unlike the clip search panel (60ms)
- [ ] **Cache `visibleIDs` in SnippetPickerViewModel** — computed property traverses all folders on every call; cache and invalidate on change

## Infrastructure
- [ ] **Plugin system** — lightweight plugin architecture where Swift packages or scripts can register clip processors (transform, filter, annotate)
