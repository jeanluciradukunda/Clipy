//
//  CPYClip.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//
//  Created by Econa77 on 2015/06/21.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa
import RealmSwift

final class CPYClip: Object {

    // MARK: - Properties
    @objc dynamic var dataPath = ""
    @objc dynamic var title = ""
    @objc dynamic var dataHash = ""
    @objc dynamic var primaryType = ""
    @objc dynamic var updateTime = 0
    @objc dynamic var thumbnailPath = ""
    @objc dynamic var isColorCode = false
    @objc dynamic var isPinned = false
    @objc dynamic var ocrText: String?
    /// A user-given name, so the clip can be fetched later, e.g. by the `clipy` command line tool.
    @objc dynamic var name: String?
    /// When set, the clip is deleted once this moment passes.
    @objc dynamic var expiresAt: Date?

    func isExpired(at now: Date = Date()) -> Bool {
        guard let expiresAt = expiresAt else { return false }
        return expiresAt <= now
    }

    // MARK: Primary Key
    override static func primaryKey() -> String? {
        return "dataHash"
    }

    /// Pinned clips first, then newest first. The sort-order preference never flips this:
    /// it decides whether copying an existing clip again refreshes its `updateTime`.
    static func historyOrder(in realm: Realm) -> Results<CPYClip> {
        return realm.objects(CPYClip.self).sorted(by: [
            SortDescriptor(keyPath: #keyPath(CPYClip.isPinned), ascending: false),
            SortDescriptor(keyPath: #keyPath(CPYClip.updateTime), ascending: false)
        ])
    }

    /// The unexpired clip with this name, matched case-insensitively.
    static func named(_ name: String, in realm: Realm, now: Date = Date()) -> CPYClip? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return realm.objects(CPYClip.self)
            .filter("name ==[c] %@", trimmed)
            .first { !$0.isExpired(at: now) }
    }

    /// Unexpired named clips, sorted by name.
    static func namedClips(in realm: Realm, now: Date = Date()) -> [CPYClip] {
        return realm.objects(CPYClip.self)
            .filter("name != nil AND name != ''")
            .filter { !$0.isExpired(at: now) }
            .sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
    }

    /// Clips whose expiry has passed.
    static func expiredClips(in realm: Realm, now: Date = Date()) -> Results<CPYClip> {
        return realm.objects(CPYClip.self).filter("expiresAt != nil AND expiresAt <= %@", now)
    }

    static func updateTime(existing: Int?, now: Int, reorderAfterPasting: Bool) -> Int {
        guard !reorderAfterPasting, let existing = existing else { return now }
        return existing
    }

}
