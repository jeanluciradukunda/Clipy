//
//  TestIsolation.swift
//
//  Clipy
//

import Foundation

/// Unit tests are hosted inside Clipy Dev itself, so without this they would start the app's services
/// and write into the real app's preferences domain (on 2026-10-10 a spec wiped a user's saved hotkeys).
enum TestIsolation {
    static let isRunningTests: Bool = {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }()

    static let suiteName = "com.clipy-app.Clipy.tests"

    /// A throwaway domain, emptied each time a test run starts.
    static let defaults: UserDefaults = {
        UserDefaults().removePersistentDomain(forName: suiteName)
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Could not create the \(suiteName) defaults suite for tests")
        }
        return defaults
    }()
}
