import Foundation
import Quick
import RealmSwift
@testable import Clipy

/// Runs before any spec. Crashing here is deliberate: a host that is not isolated must not get
/// as far as one spec, because specs write preferences and Realm data.
final class TestIsolationConfiguration: QuickConfiguration {
    override static func configure(_ configuration: QCKConfiguration) {
        precondition(TestIsolation.isRunningTests, "Clipy did not detect that it is hosting tests")
        // swiftlint:disable:next no_standard_defaults_in_tests
        precondition(AppEnvironment.current.defaults !== UserDefaults.standard,
                     "Specs would write into the real preferences of \(Bundle.main.bundleIdentifier ?? "the host app")")
        precondition(Realm.Configuration.defaultConfiguration.inMemoryIdentifier != nil,
                     "Specs would open the real Realm at \(Realm.Configuration.defaultConfiguration.fileURL?.path ?? "?")")
        // The app's launch is skipped under tests, so register the defaults it would have registered.
        CPYUtilities.registerUserDefaultKeys()
        // Specs that paste must never post a real Cmd-V into whatever app is in front.
        AppEnvironment.current.defaults.set(false, forKey: Constants.UserDefaults.inputPasteCommand)
    }
}
