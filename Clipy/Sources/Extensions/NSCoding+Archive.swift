//
//  NSCoding+Archive.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy-Dev", category: "Archive")

extension NSCoding {
    func archive() -> Data {
        do {
            return try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
        } catch {
            logger.error("Failed to archive object: \(error.localizedDescription)")
            return Data()
        }
    }
}

extension Array where Element: NSCoding {
    func archive() -> Data {
        do {
            return try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
        } catch {
            logger.error("Failed to archive array: \(error.localizedDescription)")
            return Data()
        }
    }
}
