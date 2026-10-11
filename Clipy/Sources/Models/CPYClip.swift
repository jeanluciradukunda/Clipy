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

    static func updateTime(existing: Int?, now: Int, reorderAfterPasting: Bool) -> Int {
        guard !reorderAfterPasting, let existing = existing else { return now }
        return existing
    }

}
