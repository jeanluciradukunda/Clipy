//
//  QuickPasteDigitBuffer.swift
//
//  Clipy
//
//  Collects the digits of a quick-paste-by-position gesture and decides when it is finished.
//

import AppKit
import Foundation

/// Collects the digits of a quick-paste gesture and reports the position once the gesture ends.
///
/// The completion signal depends on how the gesture is entered, which is the whole reason this
/// type exists:
///
/// - ``Mode/commandHold``: the user holds ⌘ while typing, so releasing ⌘ is an unambiguous
///   "I'm done". Any number of digits, resolved the instant the modifier goes up.
/// - ``Mode/legacyDebounce(_:)``: bare digits carry no terminator, so a lone digit has to wait out
///   a short window in case a second one follows. That ambiguity is what caps the gesture at two
///   digits and makes every single-digit select pay the wait.
///
/// The ⌘-release watcher lives here rather than in the panel views because the panels rebuild their
/// hosting view on every open (`ClipSearchWindowController.show()`), so a monitor owned by view
/// state would leak one monitor per open. Scoping it to a single gesture means it exists for
/// milliseconds and is torn down on resolve, on ``reset()``, and on deinit.
///
/// Main-thread only; the panels drive it from their key handling.
final class QuickPasteDigitBuffer {

    enum Mode: Equatable {
        case commandHold
        case legacyDebounce(TimeInterval)
    }

    /// Called with the 1-based position the gesture resolved to.
    var onResolve: ((Int) -> Void)?

    /// Called when the gesture is abandoned with Escape, so the panel can dismiss itself.
    /// SwiftUI never receives ⌘-modified Escape, so the panel cannot notice this on its own.
    var onCancel: (() -> Void)?

    /// Digits collected so far and not yet resolved.
    private(set) var pendingDigits = ""

    private var activeMode: Mode?
    private var debounce: DispatchWorkItem?
    private var gestureMonitor: Any?

    private static let escapeKeyCode: UInt16 = 53

    deinit {
        // Not calling reset(): deinit must not touch the closures, only the monitor.
        if let monitor = gestureMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    /// Records one digit of the gesture.
    func press(_ digit: Character, mode: Mode) {
        debounce?.cancel()
        debounce = nil
        activeMode = mode
        pendingDigits.append(digit)

        switch mode {
        case .commandHold:
            startWatchingForGestureEnd()
        case .legacyDebounce(let window):
            // Two digits is the ceiling here, because a third could not be distinguished from
            // the start of a new selection.
            if pendingDigits.count >= 2 {
                resolve()
                return
            }
            let work = DispatchWorkItem { [weak self] in
                guard let self, !self.pendingDigits.isEmpty else { return }
                self.resolve()
            }
            debounce = work
            DispatchQueue.main.asyncAfter(deadline: .now() + window, execute: work)
        }
    }

    /// The modifier went up, which completes a ``Mode/commandHold`` gesture and nothing else.
    func modifierReleased() {
        guard activeMode == .commandHold else { return }
        resolve()
    }

    /// Abandons the gesture in progress and reports it, so nothing is pasted.
    func cancel() {
        guard activeMode != nil else { return }
        reset()
        onCancel?()
    }

    /// Abandons any gesture in progress, so a dismissed panel cannot paste after the fact.
    func reset() {
        debounce?.cancel()
        debounce = nil
        pendingDigits = ""
        activeMode = nil
        stopWatchingForGestureEnd()
    }

    // MARK: - Private

    private func resolve() {
        let digits = pendingDigits
        debounce?.cancel()
        debounce = nil
        pendingDigits = ""
        activeMode = nil
        stopWatchingForGestureEnd()

        guard let position = Int(digits) else { return }
        onResolve?(position)
    }

    /// Watches for the two ways a held gesture can end. Both have to come from a local monitor:
    /// SwiftUI's `onModifierKeysChanged` does not observe the release, and `onKeyPress(.escape)`
    /// never fires at all while ⌘ is held, so the panel cannot see either signal itself.
    private func startWatchingForGestureEnd() {
        guard gestureMonitor == nil else { return }
        gestureMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                guard event.keyCode == Self.escapeKeyCode else { return event }
                // Swallowed, because cancel() dismisses the panel itself.
                self.cancel()
                return nil
            }
            if !event.modifierFlags.contains(.command) {
                self.modifierReleased()
            }
            return event
        }
    }

    private func stopWatchingForGestureEnd() {
        guard let monitor = gestureMonitor else { return }
        NSEvent.removeMonitor(monitor)
        gestureMonitor = nil
    }
}
