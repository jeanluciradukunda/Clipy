import Foundation
import Quick
import Nimble
@testable import Clipy

class TestIsolationSpec: QuickSpec {
    override class func spec() {

        describe("Test isolation") {

            it("keeps spec writes out of the host app's preferences") {
                let key = "kCPYTestIsolationProbe-\(UUID().uuidString)"
                AppEnvironment.current.defaults.set(true, forKey: key)
                defer { AppEnvironment.current.defaults.removeObject(forKey: key) }

                expect(AppEnvironment.current.defaults.bool(forKey: key)) == true
                // swiftlint:disable:next no_standard_defaults_in_tests
                expect(UserDefaults.standard.object(forKey: key)).to(beNil())
                let hostDomain = UserDefaults().persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
                expect(hostDomain?[key]).to(beNil())
            }

            it("never uses a real app domain as the test suite") {
                expect(TestIsolation.suiteName) != "com.clipy-app.Clipy"
                expect(TestIsolation.suiteName) != "com.clipy-app.Clipy-Dev.debug"
                expect(TestIsolation.suiteName) != Bundle.main.bundleIdentifier
            }

            it("keeps clip files out of the host app's Application Support folder") {
                let realFolder = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first ?? ""

                expect(CPYUtilities.applicationSupportFolder()).to(beginWith(NSTemporaryDirectory()))
                expect(CPYUtilities.applicationSupportFolder()).toNot(beginWith(realFolder))
            }
        }
    }
}
