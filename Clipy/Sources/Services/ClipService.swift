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
    private var monitorTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    /// When > 0, the next N clipboard changes are skipped (not saved to history).
    /// Specific pasteboard change counts that should be skipped (not saved to history).
    /// Used by ephemeral paste to prevent secrets from being stored.
    private var skippedChangeCounts = Set<Int>()
    private let skipLock = NSLock()

    /// Tell ClipService to skip the next clipboard change (ephemeral paste).
    func skipNextCapture() {
        let nextChangeCount = NSPasteboard.general.changeCount
        skipLock.lock()
        skippedChangeCounts.insert(nextChangeCount)
        skipLock.unlock()
    }

    /// Check and consume a skip token. Returns true if this capture should be skipped.
    private func shouldSkipCapture() -> Bool {
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
        // Delete Realm
        realm.transaction { realm.delete(clips) }
        // Delete stored data files
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
        let types = self.types(with: pasteboard)
        if types.isEmpty { return }

        // Excluded application
        guard !AppEnvironment.current.excludeAppService.frontProcessIsExcludedApplication() else { return }
        // Special applications
        guard !AppEnvironment.current.excludeAppService.copiedProcessIsExcludedApplications(pasteboard: pasteboard) else { return }

        // Create data
        let data = CPYClipData(pasteboard: pasteboard, types: types)
        save(with: data)
    }

    func create(with image: NSImage) {
        lock.lock(); defer { lock.unlock() }

        let data = CPYClipData(image: image)
        save(with: data)
    }

    fileprivate func save(with data: CPYClipData) {
        guard let realm = Realm.safeInstance() else { return }

        // Copy already copied history
        let isCopySameHistory = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.copySameHistory)
        if realm.object(ofType: CPYClip.self, forPrimaryKey: "\(data.hash)") != nil, !isCopySameHistory { return }
        // Don't save invalidated clip
        if let clip = realm.object(ofType: CPYClip.self, forPrimaryKey: "\(data.hash)"), clip.isInvalidated { return }

        // Don't save empty string history
        if data.isOnlyStringType && data.stringValue.isEmpty { return }

        // Overwrite same history
        let isOverwriteHistory = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.overwriteSameHistory)
        let savedHash = (isOverwriteHistory) ? data.hash : Int(arc4random() % 1000000)

        // Preserve pinned state from existing clip being overwritten
        let existingIsPinned = realm.object(ofType: CPYClip.self, forPrimaryKey: "\(savedHash)")?.isPinned ?? false

        // Saved time and path
        let unixTime = Int(Date().timeIntervalSince1970)
        let savedPath = CPYUtilities.applicationSupportFolder() + "/\(NSUUID().uuidString).data"
        // Create Realm object
        let clip = CPYClip()
        clip.dataPath = savedPath
        clip.title = data.stringValue[0...10000]
        clip.dataHash = "\(savedHash)"
        clip.updateTime = unixTime
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
                    dispatchRealm.transaction {
                        dispatchRealm.add(clip, update: .all)
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
