import Quick
import Nimble
@testable import Clipy

class UpdateVerifierSpec: QuickSpec {
    override class func spec() {

        describe("UpdateVerifier.isNewer") {
            it("offers only strictly newer versions") {
                expect(UpdateVerifier.isNewer("2.2.3", than: "2.2.2")) == true
                expect(UpdateVerifier.isNewer("2.10.0", than: "2.9.9")) == true
                expect(UpdateVerifier.isNewer("v2.3", than: "2.2.9")) == true
                expect(UpdateVerifier.isNewer("2.2.2.1", than: "2.2.2")) == true
                expect(UpdateVerifier.isNewer("2.2.2", than: "2.2.2")) == false
                expect(UpdateVerifier.isNewer("2.2.1", than: "2.2.2")) == false
                expect(UpdateVerifier.isNewer("2.9.9", than: "2.10.0")) == false
            }
        }

        describe("UpdateVerifier.mountPoint") {
            it("takes the mount point hdiutil reports") {
                let plist: [String: Any] = ["system-entities": [["content-hint": "GUID_partition_scheme"],
                                                                ["content-hint": "Apple_HFS", "mount-point": "/Volumes/Clipy 1"]]]
                let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                expect(UpdateVerifier.mountPoint(fromAttachPlist: data ?? Data())) == "/Volumes/Clipy 1"
            }

            it("finds nothing in unexpected output") {
                expect(UpdateVerifier.mountPoint(fromAttachPlist: Data("not a plist".utf8))) == nil
            }
        }

        describe("UpdateVerifier.verify") {
            it("refuses when no team identifier is known") {
                expect { try UpdateVerifier.verify(appAt: Bundle.main.bundleURL, teamIdentifier: nil) }
                    .to(throwError(UpdateVerifier.Failure.noTeamIdentifier))
            }

            it("rejects an app without a Developer ID signature from that team") {
                expect { try UpdateVerifier.verify(appAt: Bundle.main.bundleURL, teamIdentifier: "ABCDE12345") }
                    .to(throwError { (error: UpdateVerifier.Failure) in
                        guard case .signatureRejected = error else { return fail("expected signatureRejected, got \(error)") }
                    })
            }

            it("rejects an Apple-signed app that is not Developer ID signed by the team") {
                let calculator = URL(fileURLWithPath: "/System/Applications/Calculator.app")
                expect { try UpdateVerifier.verify(appAt: calculator, bundleIdentifier: "com.apple.calculator", teamIdentifier: "ABCDE12345") }
                    .to(throwError { (error: UpdateVerifier.Failure) in
                        guard case .signatureRejected = error else { return fail("expected signatureRejected, got \(error)") }
                    })
            }
        }
    }
}
