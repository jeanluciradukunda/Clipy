import Foundation
import Quick
import Nimble
@testable import Clipy

class UpdateFeedSpec: QuickSpec {
    override class func spec() {
        describe("Update feed") {
            it("does not point Sparkle at the original Clipy project's appcast") {
                expect(Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String) == nil
            }
        }
    }
}
