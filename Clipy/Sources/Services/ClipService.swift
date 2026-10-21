//
//  ClipService.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//
//  Created by Econa77 on 2016/11/17.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation
import Cocoa
import RealmSwift
import Combine
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy", category: "ClipService")

final class ClipService {

    // MARK: - Properties
    private var cachedChangeCount: Int = 0
    private var storeTypes = [String: NSNumber]()
    private let lock = NSRecursiveLock(name: "com.clipy-app.Clipy.ClipUpdatable")
    private let keyQueue = DispatchQueue(label: "com.clipy-app.Clipy.ClipKeys", qos: .userInitiated)
    private var monitorTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    /// When > 0, the next N clipboard changes are skipped (not saved to history).
    /// Specific pasteboard change counts that should be skipped (not saved to history).
    /// Used by ephemeral paste to prevent secrets from being stored.
    private var skippedChangeCounts = Set<Int>()
    private let skipLock = NSLock()

    /// Skip the clipboard change already on the pasteboard (ephemeral paste): call it after writing.
    func skipNextCapture() {
        let nextChangeCount = NSPasteboard.general.changeCount
        skipLock.lock()
        skippedChangeCounts.insert(nextChangeCount)
        skipLock.unlock()
    }

    /// Check and consume a skip token. Returns true if this capture should be skipped.
    func shouldSkipCapture() -> Bool {
        let current = NSPasteboard.general.changeCount
        skipLock.lock()
        defer { skipLock.unlock() }
        if skippedChangeCounts.remove(current) != nil {
            return true
        }
        return false
    }

    // MARK: - Thumbnail Cache
    private static let thumbnailCache = NSCache<NSString, NSImage>()

    static func cachedThumbnail(forKey key: String) -> NSImage? {
        return thumbnailCache.object(forKey: key as NSString)
    }

    static func cacheThumbnail(_ image: NSImage, forKey key: String) {
        thumbnailCache.setObject(image, forKey: key as NSString)
    }

    static func removeCachedThumbnail(forKey key: String) {
        thumbnailCache.removeObject(forKey: key as NSString)
    }

    // MARK: - Clips
    func startMonitoring() {
        stopMonitoring()

        // Observe store types changes
        AppEnvironment.current.defaults
            .publisher(for: \.clipyStoreTypes)
            .sink { [weak self] types in
                if let types = types as? [String: NSNumber] {
                    self?.storeTypes = types
                }
            }
            .store(in: &cancellables)

        // Initialize store types
        if let types = AppEnvironment.current.defaults.object(forKey: Constants.UserDefaults.storeTypes) as? [String: NSNumber] {
            storeTypes = types
        }

        // Pasteboard polling using Timer on main run loop
        cachedChangeCount = NSPasteboard.general.changeCount
        monitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self = self else { break }
                let currentCount = NSPasteboard.general.changeCount
                if currentCount != self.cachedChangeCount {
                    self.cachedChangeCount = currentCount
                    self.create()
                }
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        cancellables.removeAll()
    }

    func clearAll() {
        guard let realm = Realm.safeInstance() else { return }
        let includePinned = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.clearHistoryIncludesPinned)
        let clips: Results<CPYClip>
        if includePinned {
            clips = realm.objects(CPYClip.self)
        } else {
            clips = realm.objects(CPYClip.self).filter("isPinned == false")
        }

        // Delete cached thumbnails
        clips
            .filter { !$0.thumbnailPath.isEmpty }
            .map { $0.thumbnailPath }
            .forEach { ClipService.removeCachedThumbnail(forKey: $0) }
        // Results is lazy: copy the paths out before the delete empties it
        let dataPaths = Array(clips.map { $0.dataPath }.filter { !$0.isEmpty })
        // Delete Realm
        realm.transaction { realm.delete(clips) }
        // Delete stored data files directly: cleanFiles refuses to sweep when the
        // Realm has zero clips, so cleared clips' files must be removed here
        dataPaths.forEach { CPYUtilities.deleteData(at: $0) }
        AppEnvironment.current.dataCleanService.cleanDatas()
    }

    func delete(with clip: CPYClip) {
        guard let realm = Realm.safeInstance() else { return }
        let path = clip.thumbnailPath
        if !path.isEmpty {
            ClipService.removeCachedThumbnail(forKey: path)
        }
        realm.transaction { realm.delete(clip) }
    }

    func togglePin(for clip: CPYClip) {
        guard let realm = Realm.safeInstance() else { return }
        guard let managedClip = realm.object(ofType: CPYClip.self, forPrimaryKey: clip.dataHash) else { return }
        realm.transaction {
            managedClip.isPinned = !managedClip.isPinned
        }
    }

    func incrementChangeCount() {
        cachedChangeCount += 1
    }
}

// MARK: - Create Clip
extension ClipService {
    fileprivate func create() {
        lock.lock(); defer { lock.unlock() }

        // Ephemeral paste: skip this clipboard change
        if shouldSkipCapture() {
            logger.debug("Skipping ephemeral clipboard capture")
            return
        }

        // Store types
        if !storeTypes.values.contains(NSNumber(value: true)) { return }
        // Pasteboard types
        let pasteboard = NSPasteboard.general
        if Self.isMarkedPrivate(pasteboard.types ?? []) { return }
        let types = self.types(with: pasteboard)
        if types.isEmpty { return }

        // Excluded application
        guard !AppEnvironment.current.excludeAppService.frontProcessIsExcludedApplication() else { return }
        // Special applications
        guard !AppEnvironment.current.excludeAppService.copiedProcessIsExcludedApplications(pasteboard: pasteboard) else { return }

        // Create data
        let data = CPYClipData(pasteboard: pasteboard, types: types)
        saveWithKeysOffMain(data)
    }

    func create(with image: NSImage) {
        lock.lock(); defer { lock.unlock() }

        let data = CPYClipData(image: image)
        saveWithKeysOffMain(data)
    }

    /// The serial queue keeps clips in capture order; the save itself stays on the main thread.
    private func saveWithKeysOffMain(_ data: CPYClipData) {
        keyQueue.async { [weak self] in
            let legacyKey: String? = autoreleasepool {
                data.prepareKeys()
                return Self.legacyDuplicateKey(for: data, in: Realm.safeInstance())
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.lock.lock(); defer { self.lock.unlock() }
                self.save(with: data, replacingLegacyKey: legacyKey)
            }
        }
    }

    /// The key of a clip an earlier release saved with this same content under its old, collision-prone
    /// key, so upgrading does not list it twice. A different clip that shared the old key is left alone.
    static func legacyDuplicateKey(for data: CPYClipData, in realm: Realm?) -> String? {
        guard let legacyHash = data.legacyHash, legacyHash != data.hash,
              let legacyClip = realm?.object(ofType: CPYClip.self, forPrimaryKey: "\(legacyHash)"),
              let stored = NSKeyedUnarchiver.unarchiveObject(withFile: legacyClip.dataPath) as? CPYClipData,
              stored.hash == data.hash else { return nil }
        return legacyClip.dataHash
    }

    /// `transaction` swallows a failed commit, so the old clip's files go only once its record is gone.
    static func removeReplacedLegacyFiles(_ files: (dataPath: String, thumbnailPath: String), key: String, in realm: Realm) {
        guard realm.object(ofType: CPYClip.self, forPrimaryKey: key) == nil else { return }
        CPYUtilities.deleteData(at: files.dataPath)
        if !files.thumbnailPath.isEmpty { removeCachedThumbnail(forKey: files.thumbnailPath) }
    }

    /// Password managers and other apps flag secrets and short-lived content with these
    /// nspasteboard.org markers; such content is never captured, whatever the exclusion list says.
    static let privateMarkerTypes: Set<NSPasteboard.PasteboardType> = [
        NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
        NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
        NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType")
    ]

    static func isMarkedPrivate(_ types: [NSPasteboard.PasteboardType]) -> Bool {
        return types.contains { privateMarkerTypes.contains($0) }
    }

    /// Without "overwrite same history" every clip needs its own key; a random number in a million
    /// could land on an existing clip and replace it.
    static func storageKey(for data: CPYClipData, overwritingSameHistory: Bool) -> String {
        return overwritingSameHistory ? "\(data.hash)" : UUID().uuidString
    }

    fileprivate func save(with data: CPYClipData, replacingLegacyKey legacyKey: String? = nil) {
        guard let realm = Realm.safeInstance() else { return }

        // Copy already copied history
        let isCopySameHistory = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.copySameHistory)
        let isAlreadySaved = realm.object(ofType: CPYClip.self, forPrimaryKey: "\(data.hash)") != nil || legacyKey != nil
        if isAlreadySaved, !isCopySameHistory { return }
        // Don't save invalidated clip
        if let clip = realm.object(ofType: CPYClip.self, forPrimaryKey: "\(data.hash)"), clip.isInvalidated { return }

        // Don't save empty string history
        if data.isOnlyStringType && data.stringValue.isEmpty { return }

        // Overwrite same history
        let isOverwriteHistory = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.overwriteSameHistory)
        let savedKey = Self.storageKey(for: data, overwritingSameHistory: isOverwriteHistory)

        let replacedLegacyKey = isOverwriteHistory ? legacyKey : nil
        let legacyClip = replacedLegacyKey.flatMap { realm.object(ofType: CPYClip.self, forPrimaryKey: $0) }
        let legacyIsPinned = legacyClip?.isPinned ?? false

        // Preserve pinned state from existing clip being overwritten
        let existingClip = realm.object(ofType: CPYClip.self, forPrimaryKey: savedKey)
        let existingIsPinned = (existingClip?.isPinned ?? false) || legacyIsPinned
        let reorderAfterPasting = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.reorderClipsAfterPasting)

        // Saved time and path
        let unixTime = Int(Date().timeIntervalSince1970)
        let savedPath = CPYUtilities.applicationSupportFolder() + "/\(NSUUID().uuidString).data"
        // Create Realm object
        let clip = CPYClip()
        clip.dataPath = savedPath
        clip.title = data.stringValue[0...10000]
        clip.dataHash = savedKey
        clip.updateTime = CPYClip.updateTime(existing: (existingClip ?? legacyClip)?.updateTime, now: unixTime, reorderAfterPasting: reorderAfterPasting)
        clip.primaryType = data.primaryType?.rawValue ?? ""
        clip.isPinned = existingIsPinned

        DispatchQueue.main.async {
            // Save thumbnail image
            if let thumbnailImage = data.thumbnailImage {
                ClipService.cacheThumbnail(thumbnailImage, forKey: "\(unixTime)")
                clip.thumbnailPath = "\(unixTime)"
            }
            if let colorCodeImage = data.colorCodeImage {
                ClipService.cacheThumbnail(colorCodeImage, forKey: "\(unixTime)")
                clip.thumbnailPath = "\(unixTime)"
                clip.isColorCode = true
            }
            // Save Realm and .data file
            guard let dispatchRealm = Realm.safeInstance() else { return }
            if CPYUtilities.prepareSaveToPath(CPYUtilities.applicationSupportFolder()) {
                if NSKeyedArchiver.archiveRootObject(data, toFile: savedPath) {
                    var replacedLegacyFiles: (dataPath: String, thumbnailPath: String)?
                    dispatchRealm.transaction {
                        if let key = replacedLegacyKey, let legacy = dispatchRealm.object(ofType: CPYClip.self, forPrimaryKey: key) {
                            replacedLegacyFiles = (legacy.dataPath, legacy.thumbnailPath)
                            dispatchRealm.delete(legacy)
                        }
                        dispatchRealm.add(clip, update: .all)
                    }
                    if let files = replacedLegacyFiles, let key = replacedLegacyKey {
                        ClipService.removeReplacedLegacyFiles(files, key: key, in: dispatchRealm)
                    }
                    UsageMetricsService.shared.track(.clipsCopied)
                    // Run auto-trigger plugins on string content (short-circuits when none registered)
                    if PluginManager.shared.hasAutoPlugins, !data.stringValue.isEmpty {
                        PluginManager.shared.runAutoPlugins(input: data.stringValue)
                    }
                    // Immediately evict oldest non-pinned clips over the limit
                    AppEnvironment.current.dataCleanService.cleanDatas()
                }
            }
        }
    }

    private func types(with pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        let types = pasteboard.types?.filter { canSave(with: $0) } ?? []
        return NSOrderedSet(array: types).array as? [NSPasteboard.PasteboardType] ?? []
    }

    private func canSave(with type: NSPasteboard.PasteboardType) -> Bool {
        let dictionary = CPYClipData.availableTypesDictinary
        guard let value = dictionary[type] else { return false }
        guard let number = storeTypes[value] else { return false }
        return number.boolValue
    }
}

// MARK: - UserDefaults KVO Bridge
private extension UserDefaults {
    @objc var clipyStoreTypes: Any? {
        return object(forKey: Constants.UserDefaults.storeTypes)
    }
}
