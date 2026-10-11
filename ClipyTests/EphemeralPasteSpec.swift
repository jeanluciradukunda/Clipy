import Quick
import Nimble
@testable import Clipy

class EphemeralPasteSpec: QuickSpec {
    override class func spec() {

        describe("Ephemeral paste") {
            beforeEach {
                AppEnvironment.current.defaults.set(0, forKey: Constants.UserDefaults.ephemeralAutoClearSeconds)
            }

            it("is skipped by the next capture, so the output never reaches history") {
                AppEnvironment.current.pasteService.pasteEphemeral(with: "script output: hunter2")
                expect(AppEnvironment.current.clipService.shouldSkipCapture()) == true
            }

            it("skips that one capture only") {
                AppEnvironment.current.pasteService.pasteEphemeral(with: "script output: hunter2")
                _ = AppEnvironment.current.clipService.shouldSkipCapture()
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("an ordinary copy", forType: .string)
                expect(AppEnvironment.current.clipService.shouldSkipCapture()) == false
            }
        }
    }
}
