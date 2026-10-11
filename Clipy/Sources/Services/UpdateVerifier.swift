//
//  UpdateVerifier.swift
//
//  Clipy
//

import Foundation
import Security

enum UpdateVerifier {

    /// The fork's Apple Developer team identifier, as on the Developer ID certificate release.yml signs
    /// with. Empty means "the team that signed the running app".
    static let pinnedTeamIdentifier = ""

    enum Failure: Error, Equatable {
        case noTeamIdentifier
        case unreadableCode(OSStatus)
        case invalidRequirement(OSStatus)
        case signatureRejected(OSStatus)
        case wrongBundleIdentifier(String?)
    }

    /// Whether `candidate` is a strictly newer dotted version than `current` ("2.10.0" > "2.9.1").
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        func parts(_ version: String) -> [Int] {
            let trimmed = version.hasPrefix("v") ? String(version.dropFirst()) : version
            return trimmed.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
        }
        let lhs = parts(candidate), rhs = parts(current)
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0, right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    /// The mount point `hdiutil attach -plist` reports, so the app is taken from the volume just mounted.
    static func mountPoint(fromAttachPlist data: Data) -> String? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]] else { return nil }
        return entities.compactMap { $0["mount-point"] as? String }.first
    }

    static func runningTeamIdentifier() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code = code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode = staticCode else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dictionary = info as? [String: Any] else { return nil }
        return dictionary[kSecCodeInfoTeamIdentifier as String] as? String
    }

    /// Fails closed: the app must carry a valid Developer ID signature from the expected team, with
    /// every nested framework intact, and Clipy's bundle identifier.
    static func verify(appAt url: URL, bundleIdentifier: String? = Bundle.main.bundleIdentifier,
                       teamIdentifier: String? = pinnedTeamIdentifier.isEmpty ? runningTeamIdentifier() : pinnedTeamIdentifier) throws {
        guard let team = teamIdentifier, !team.isEmpty else { throw Failure.noTeamIdentifier }
        var staticCode: SecStaticCode?
        var status = SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode)
        guard status == errSecSuccess, let code = staticCode else { throw Failure.unreadableCode(status) }

        let developerID = "anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists"
            + " and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = \"\(team)\""
        var requirement: SecRequirement?
        status = SecRequirementCreateWithString(developerID as CFString, [], &requirement)
        guard status == errSecSuccess, let requirement = requirement else { throw Failure.invalidRequirement(status) }

        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        status = SecStaticCodeCheckValidity(code, flags, requirement)
        guard status == errSecSuccess else { throw Failure.signatureRejected(status) }

        let candidateIdentifier = Bundle(url: url)?.bundleIdentifier
        guard candidateIdentifier == bundleIdentifier else { throw Failure.wrongBundleIdentifier(candidateIdentifier) }
    }
}
