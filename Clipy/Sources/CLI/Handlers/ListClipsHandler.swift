//
//  ListClipsHandler.swift
//
//  Clipy
//
//  `clipy list`: the names and expiry of every named clip, without their content.
//

import Foundation
import RealmSwift

@MainActor
struct ListClipsHandler: CLICommandHandler {
    let name = CLIListCommand.name
    let requiresUnlock = true

    func handle(_ request: CLIRequest) async throws -> CLIJSON? {
        guard let realm = Realm.safeInstance() else {
            throw CLIError(code: .internalError, message: "Clipy could not open its clip history")
        }
        let clips = CPYClip.namedClips(in: realm).map {
            CLINamedClip(name: $0.name ?? "", expiresAt: $0.expiresAt)
        }
        return try CLIJSON(encoding: CLIListCommand.Result(clips: clips))
    }
}
