//
//  ExcludeAppService.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//
//  Created by Econa77 on 2017/02/10.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa
import Combine

final class ExcludeAppService {

    // MARK: - Properties
    fileprivate(set) var applications = [CPYAppInfo]()
    private var frontApplication: NSRunningApplication?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialize
    init(applications: [CPYAppInfo]) {
        self.applications = applications
    }

}

// MARK: - Monitor Applications
extension ExcludeAppService {
    func startMonitoring() {
        cancellables.removeAll()
        // Monitoring top active application
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .compactMap { $0.userInfo?["NSWorkspaceApplicationKey"] as? NSRunningApplication }
            .sink { [weak self] app in
                self?.frontApplication = app
            }
            .store(in: &cancellables)
    }
}

// MARK: - Exclude
extension ExcludeAppService {
    func frontProcessIsExcludedApplication() -> Bool {
        if applications.isEmpty { return false }
        guard let frontApplicationIdentifier = frontApplication?.bundleIdentifier else { return false }

        for app in applications where app.identifier == frontApplicationIdentifier {
            return true
        }
        return false
    }
}

// MARK: - Add or Delete
extension ExcludeAppService {
    func add(with appInfo: CPYAppInfo) {
        if applications.contains(appInfo) { return }
        applications.append(appInfo)
        save()
    }

    func delete(with appInfo: CPYAppInfo) {
        applications = applications.filter { $0 != appInfo }
        save()
    }

    func delete(with index: Int) {
        delete(with: applications[index])
    }

    private func save() {
        let data = applications.archive()
        AppEnvironment.current.defaults.set(data, forKey: Constants.UserDefaults.excludeApplications)
    }
}

// MARK: - Special Applications
extension ExcludeAppService {
    private enum Application: String {
        case onePassword = "com.agilebits.onepassword"

        private var macApplicationIdentifiers: [String] {
            switch self {
            case .onePassword:
                return ["com.agilebits.onepassword-osx",
                        "com.agilebits.onepassword7",
                        "com.1password.1password"]
            }
        }

        func isExcluded(applications: [CPYAppInfo]) -> Bool {
            return !applications.filter { macApplicationIdentifiers.contains($0.identifier) }.isEmpty
        }
    }

    func copiedProcessIsExcludedApplications(pasteboard: NSPasteboard) -> Bool {
        guard let types = pasteboard.types else { return false }
        guard let application = types.compactMap({ Application(rawValue: $0.rawValue) }).first else { return false }
        return application.isExcluded(applications: applications)
    }
}
