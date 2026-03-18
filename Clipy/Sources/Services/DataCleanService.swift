//
//  DataCleanService.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//
//  Created by Econa77 on 2016/11/20.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation
import RealmSwift
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy-Dev", category: "DataClean")

final class DataCleanService {

    // MARK: - Properties
    private var cleanTask: Task<Void, Never>?

    // MARK: - Monitoring
    func startMonitoring() {
        stopMonitoring()
        // Clean data every 30 minutes
        cleanTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60 * 30))
                guard let self = self else { break }
                self.cleanDatas()
            }
        }
    }

    func stopMonitoring() {
        cleanTask?.cancel()
        cleanTask = nil
    }

    // MARK: - Delete Data
    func cleanDatas() {
        guard let realm = Realm.safeInstance() else {
            logger.error("Cannot open Realm for data cleanup")
            return
        }
        let flowHistories = overflowingClips(with: realm)
        flowHistories
            .filter { !$0.isInvalidated && !$0.thumbnailPath.isEmpty }
            .map { $0.thumbnailPath }
            .forEach { ClipService.removeCachedThumbnail(forKey: $0) }
        realm.transaction { realm.delete(flowHistories) }
        cleanFiles(with: realm)
    }

    private func overflowingClips(with realm: Realm) -> Results<CPYClip> {
        let clips = realm.objects(CPYClip.self).sorted(byKeyPath: #keyPath(CPYClip.updateTime), ascending: false)
        let maxHistorySize = max(1, AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.maxHistorySize))

        if clips.count <= maxHistorySize { return realm.objects(CPYClip.self).filter("FALSEPREDICATE") }
        let lastClip = clips[maxHistorySize - 1]
        if lastClip.isInvalidated { return realm.objects(CPYClip.self).filter("FALSEPREDICATE") }

        let updateTime = lastClip.updateTime
        let targetClips = realm.objects(CPYClip.self).filter("updateTime < %d AND isPinned == false", updateTime)

        return targetClips
    }

    private func cleanFiles(with realm: Realm) {
        let fileManager = FileManager.default
        guard let paths = try? fileManager.contentsOfDirectory(atPath: CPYUtilities.applicationSupportFolder()) else { return }

        let allClipPaths = Array(realm.objects(CPYClip.self)
            .filter { !$0.isInvalidated }
            .compactMap { $0.dataPath.components(separatedBy: "/").last })

        DispatchQueue.main.async {
            Set(allClipPaths).symmetricDifference(paths)
                .map { CPYUtilities.applicationSupportFolder() + "/" + "\($0)" }
                .forEach { CPYUtilities.deleteData(at: $0) }
        }
    }
}
