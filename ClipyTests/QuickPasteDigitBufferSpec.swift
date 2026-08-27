import Quick
import Nimble
@testable import Clipy

// swiftlint:disable function_body_length

class QuickPasteDigitBufferSpec: QuickSpec {
    override class func spec() {

        describe("command-hold mode") {
            it("accumulates digits without resolving until the modifier is released") {
                var resolved = [Int]()
                let buffer = QuickPasteDigitBuffer()
                buffer.onResolve = { resolved.append($0) }

                buffer.press("1", mode: .commandHold)
                buffer.press("5", mode: .commandHold)
                expect(resolved).to(beEmpty())

                buffer.modifierReleased()
                expect(resolved) == [15]
            }

            it("has no two-digit ceiling") {
                var resolved = [Int]()
                let buffer = QuickPasteDigitBuffer()
                buffer.onResolve = { resolved.append($0) }

                buffer.press("1", mode: .commandHold)
                buffer.press("5", mode: .commandHold)
                buffer.press("3", mode: .commandHold)
                buffer.modifierReleased()

                expect(resolved) == [153]
            }

            it("resolves a single digit immediately on release, with no debounce wait") {
                var resolved = [Int]()
                let buffer = QuickPasteDigitBuffer()
                buffer.onResolve = { resolved.append($0) }

                buffer.press("7", mode: .commandHold)
                buffer.modifierReleased()

                expect(resolved) == [7]
            }

            it("does nothing when the modifier is released with no digits typed") {
                var resolved = [Int]()
                let buffer = QuickPasteDigitBuffer()
                buffer.onResolve = { resolved.append($0) }

                buffer.modifierReleased()

                expect(resolved).to(beEmpty())
            }

            it("does not resolve twice for one press of the modifier") {
                var resolved = [Int]()
                let buffer = QuickPasteDigitBuffer()
                buffer.onResolve = { resolved.append($0) }

                buffer.press("4", mode: .commandHold)
                buffer.modifierReleased()
                buffer.modifierReleased()

                expect(resolved) == [4]
            }

            it("abandons the gesture on cancel and reports it, so the panel can dismiss") {
                var resolved = [Int]()
                var cancelled = 0
                let buffer = QuickPasteDigitBuffer()
                buffer.onResolve = { resolved.append($0) }
                buffer.onCancel = { cancelled += 1 }

                buffer.press("2", mode: .commandHold)
                buffer.cancel()

                expect(resolved).to(beEmpty())
                expect(cancelled) == 1
                expect(buffer.pendingDigits).to(beEmpty())
            }

            it("does not paste when the modifier is released after a cancel") {
                var resolved = [Int]()
                let buffer = QuickPasteDigitBuffer()
                buffer.onResolve = { resolved.append($0) }

                buffer.press("2", mode: .commandHold)
                buffer.cancel()
                buffer.modifierReleased()

                expect(resolved).to(beEmpty())
            }

            it("does not report a cancel when no gesture is in progress") {
                var cancelled = 0
                let buffer = QuickPasteDigitBuffer()
                buffer.onCancel = { cancelled += 1 }

                buffer.cancel()

                expect(cancelled) == 0
            }

            it("discards buffered digits when reset, so a dismissed panel cannot paste later") {
                var resolved = [Int]()
                let buffer = QuickPasteDigitBuffer()
                buffer.onResolve = { resolved.append($0) }

                buffer.press("9", mode: .commandHold)
                buffer.reset()
                buffer.modifierReleased()

                expect(resolved).to(beEmpty())
            }
        }

        describe("legacy debounce mode") {
            it("still resolves two digits immediately, preserving today's behaviour") {
                var resolved = [Int]()
                let buffer = QuickPasteDigitBuffer()
                buffer.onResolve = { resolved.append($0) }

                buffer.press("1", mode: .legacyDebounce(0.08))
                buffer.press("5", mode: .legacyDebounce(0.08))

                expect(resolved) == [15]
            }

            it("waits for the debounce before resolving a lone digit") {
                var resolved = [Int]()
                let buffer = QuickPasteDigitBuffer()
                buffer.onResolve = { resolved.append($0) }

                buffer.press("3", mode: .legacyDebounce(0.08))
                expect(resolved).to(beEmpty())
                expect(buffer.pendingDigits) == "3"
            }

            it("ignores a modifier release, which is not its completion signal") {
                var resolved = [Int]()
                let buffer = QuickPasteDigitBuffer()
                buffer.onResolve = { resolved.append($0) }

                buffer.press("3", mode: .legacyDebounce(0.08))
                buffer.modifierReleased()

                expect(resolved).to(beEmpty())
                expect(buffer.pendingDigits) == "3"
            }
        }
    }
}

// swiftlint:enable function_body_length
