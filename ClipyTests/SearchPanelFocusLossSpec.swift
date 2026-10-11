import Quick
import Nimble
@testable import Clipy

class SearchPanelFocusLossSpec: QuickSpec {
    override class func spec() {

        let controller = ClipSearchWindowController.shared

        beforeEach {
            controller.show()
        }

        afterEach {
            controller.dismiss()
        }

        describe("ClipSearchWindowController.dismissOnFocusLoss") {
            it("closes the panel when the setting is on") {
                controller.dismissOnFocusLoss(enabled: true)
                expect(controller.window?.isVisible) == false
            }

            it("leaves the panel open when the setting is off") {
                controller.dismissOnFocusLoss(enabled: false)
                expect(controller.window?.isVisible) == true
            }
        }
    }
}
