# Clipy Dev — Feature Wishlist

Track upcoming features. Mark `[x]` when complete.

---

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

## Infrastructure
- [ ] **Plugin system** — lightweight plugin architecture where Swift packages or scripts can register clip processors (transform, filter, annotate)
