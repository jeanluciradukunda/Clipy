import Quick
import Nimble
@testable import Clipy

class LoginItemSpec: QuickSpec {
    override class func spec() {
        describe("AppDelegate.appliesLoginItemAtLaunch") {
            it("is off in Clipy Dev, so launching a build never prompts or replaces a login item") {
                expect(AppDelegate.appliesLoginItemAtLaunch) == false
            }
        }
    }
}
