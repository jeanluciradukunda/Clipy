//
//  Realm+NoCatch.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation
import RealmSwift
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy-Dev", category: "Realm")

extension Realm {
    func transaction(_ block: (() throws -> Void)) {
        do {
            try write(block)
        } catch {
            logger.error("Realm write failed: \(error.localizedDescription)")
        }
    }
}

extension Realm {
    static func safeInstance() -> Realm? {
        do {
            return try Realm()
        } catch {
            logger.error("Failed to open Realm: \(error.localizedDescription)")
            return nil
        }
    }
}
