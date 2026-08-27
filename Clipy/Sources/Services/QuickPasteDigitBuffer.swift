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

    /// Digits collected so far and not yet resolved.
    private(set) var pendingDigits = ""

    private var activeMode: Mode?
    private var debounce: DispatchWorkItem?
    private var flagsMonitor: Any?

    deinit {
        // Not calling reset(): deinit must not touch the closure, only the monitor.
        if let monitor = flagsMonitor {
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
            startWatchingForModifierRelease()
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

    /// Abandons any gesture in progress, so a dismissed panel cannot paste after the fact.
    func reset() {
        debounce?.cancel()
        debounce = nil
        pendingDigits = ""
        activeMode = nil
        stopWatchingForModifierRelease()
    }

    // MARK: - Private

    private func resolve() {
        let digits = pendingDigits
        debounce?.cancel()
        debounce = nil
        pendingDigits = ""
        activeMode = nil
        stopWatchingForModifierRelease()

        guard let position = Int(digits) else { return }
        onResolve?(position)
    }

    private func startWatchingForModifierRelease() {
        guard flagsMonitor == nil else { return }
        // SwiftUI's onModifierKeysChanged does not observe this, so use the local monitor instead.
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            if !event.modifierFlags.contains(.command) {
                self?.modifierReleased()
            }
            return event
        }
    }

    private func stopWatchingForModifierRelease() {
        guard let monitor = flagsMonitor else { return }
        NSEvent.removeMonitor(monitor)
        flagsMonitor = nil
    }
}
