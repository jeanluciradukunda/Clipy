//
//  GetClipHandler.swift
//
//  Clipy
//
//  `clipy get <name>`: the text of the named clip.
//

import Foundation
import RealmSwift

@MainActor
struct GetClipHandler: CLICommandHandler {
    let name = CLIGetCommand.name
    let requiresUnlock = true

    func handle(_ request: CLIRequest) async throws -> CLIJSON? {
        let args = try request.arguments(CLIGetCommand.Arguments.self)
        let wanted = args.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty else {
            throw CLIError(code: .badRequest, message: "A clip name is required")
        }
        guard let realm = Realm.safeInstance() else {
            throw CLIError(code: .internalError, message: "Clipy could not open its clip history")
        }

        guard let clip = CPYClip.named(wanted, in: realm) else {
            let hasExpired = realm.objects(CPYClip.self)
                .filter("name ==[c] %@", wanted)
                .contains { $0.isExpired() }
            if hasExpired {
                // Delete it now rather than waiting for the cleanup sweep
                AppEnvironment.current.clipService.purgeExpired()
                throw CLIError(code: .expired, message: "Clip '\(wanted)' has expired and was deleted")
            }
            throw CLIError(code: .notFound, message: "No clip is named '\(wanted)'")
        }

        guard let data = NSKeyedUnarchiver.unarchiveObject(withFile: clip.dataPath) as? CPYClipData,
              !data.stringValue.isEmpty else {
            throw CLIError(code: .notText, message: "Clip '\(wanted)' has no text to print")
        }
        let result = CLIGetCommand.Result(name: clip.name ?? wanted, content: data.stringValue, expiresAt: clip.expiresAt)
        return try CLIJSON(encoding: result)
    }
}
