import Quick
import Nimble
@testable import Clipy

class SelfUpdateSpec: QuickSpec {
    override class func spec() {
        describe("Self-update") {
            it("is unavailable in Clipy Dev, so it can't replace the installed release app") {
                expect(SelfUpdate.isAvailable) == false
            }
        }
    }
}
