//
//  NSUserDefaults+ArchiveData.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation
import Cocoa
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy", category: "Defaults")

extension UserDefaults {
    func setArchiveData<T: NSCoding>(_ object: T, forKey key: String) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: false)
            set(data, forKey: key)
        } catch {
            logger.error("Failed to archive for key \(key): \(error.localizedDescription)")
        }
    }

    func archiveDataForKey<T: NSObject & NSCoding>(_: T.Type, key: String) -> T? {
        guard let data = object(forKey: key) as? Data else { return nil }
        do {
            let obj = try NSKeyedUnarchiver.unarchivedObject(ofClass: T.self, from: data)
            return obj
        } catch {
            // Fallback to legacy unarchiver for backward compatibility
            return NSKeyedUnarchiver.unarchiveObject(with: data) as? T
        }
    }
}
