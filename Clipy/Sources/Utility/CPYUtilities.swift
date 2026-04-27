//
//  CPYUtilities.swift
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
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy", category: "Utilities")

final class CPYUtilities {

    static func initSDKs() {
        AppEnvironment.current.defaults.register(defaults: ["NSApplicationCrashOnExceptions": true])
        guard AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.collectCrashReport) else { return }
        logger.info("Application launched")
    }

    static func registerUserDefaultKeys() {
        var defaultValues = [String: Any]()

        defaultValues.updateValue(HotKeyService.defaultKeyCombos, forKey: Constants.UserDefaults.hotKeys)
        /* General */
        defaultValues.updateValue(NSNumber(value: false), forKey: Constants.UserDefaults.loginItem)
        defaultValues.updateValue(NSNumber(value: false), forKey: Constants.UserDefaults.suppressAlertForLoginItem)
        defaultValues.updateValue(NSNumber(value: 30), forKey: Constants.UserDefaults.maxHistorySize)
        defaultValues.updateValue(NSNumber(value: 1), forKey: Constants.UserDefaults.showStatusItem)
        defaultValues.updateValue(AppDelegate.storeTypesDictinary(), forKey: Constants.UserDefaults.storeTypes)
        defaultValues.updateValue(NSNumber(value: true), forKey: Constants.UserDefaults.inputPasteCommand)
        defaultValues.updateValue(NSNumber(value: true), forKey: Constants.UserDefaults.reorderClipsAfterPasting)
        defaultValues.updateValue(NSNumber(value: true), forKey: Constants.UserDefaults.collectCrashReport)

        /* Menu */
        defaultValues.updateValue(NSNumber(value: 16), forKey: Constants.UserDefaults.menuIconSize)
        defaultValues.updateValue(NSNumber(value: 20), forKey: Constants.UserDefaults.maxMenuItemTitleLength)
        defaultValues.updateValue(NSNumber(value: 0), forKey: Constants.UserDefaults.numberOfItemsPlaceInline)
        defaultValues.updateValue(NSNumber(value: 10), forKey: Constants.UserDefaults.numberOfItemsPlaceInsideFolder)
        defaultValues.updateValue(NSNumber(value: false), forKey: Constants.UserDefaults.menuItemsTitleStartWithZero)
        defaultValues.updateValue(NSNumber(value: true), forKey: Constants.UserDefaults.showAlertBeforeClearHistory)
        defaultValues.updateValue(NSNumber(value: true), forKey: Constants.UserDefaults.addClearHistoryMenuItem)
        defaultValues.updateValue(NSNumber(value: true), forKey: Constants.UserDefaults.showIconInTheMenu)
        defaultValues.updateValue(NSNumber(value: true), forKey: Constants.UserDefaults.menuItemsAreMarkedWithNumbers)
        defaultValues.updateValue(NSNumber(value: false), forKey: Constants.UserDefaults.addNumericKeyEquivalents)
        defaultValues.updateValue(NSNumber(value: true), forKey: Constants.UserDefaults.showToolTipOnMenuItem)
        defaultValues.updateValue(NSNumber(value: true), forKey: Constants.UserDefaults.showImageInTheMenu)
        defaultValues.updateValue(NSNumber(value: 200), forKey: Constants.UserDefaults.maxLengthOfToolTip)
        defaultValues.updateValue(NSNumber(value: 100), forKey: Constants.UserDefaults.thumbnailWidth)
        defaultValues.updateValue(NSNumber(value: 32), forKey: Constants.UserDefaults.thumbnailHeight)
        defaultValues.updateValue(NSNumber(value: true), forKey: Constants.UserDefaults.overwriteSameHistory)
        defaultValues.updateValue(NSNumber(value: true), forKey: Constants.UserDefaults.copySameHistory)
        defaultValues.updateValue(NSNumber(value: true), forKey: Constants.UserDefaults.showColorPreviewInTheMenu)
        defaultValues.updateValue(NSNumber(value: false), forKey: Constants.UserDefaults.clearHistoryIncludesPinned)
        defaultValues.updateValue(NSNumber(value: 30), forKey: Constants.UserDefaults.ephemeralAutoClearSeconds)

        /* Snippets */
        defaultValues.updateValue(NSNumber(value: true), forKey: Constants.Snippets.useModernPicker)

        /* Updates */
        defaultValues.updateValue(NSNumber(value: true), forKey: Constants.Update.enableAutomaticCheck)
        defaultValues.updateValue(NSNumber(value: 86400), forKey: Constants.Update.checkInterval)

        /* Beta */
        defaultValues.updateValue(NSNumber(value: true), forKey: Constants.Beta.pastePlainText)
        defaultValues.updateValue(NSNumber(value: 0), forKey: Constants.Beta.pastePlainTextModifier)
        defaultValues.updateValue(NSNumber(value: false), forKey: Constants.Beta.deleteHistory)
        defaultValues.updateValue(NSNumber(value: 0), forKey: Constants.Beta.deleteHistoryModifier)
        defaultValues.updateValue(NSNumber(value: false), forKey: Constants.Beta.pasteAndDeleteHistory)
        defaultValues.updateValue(NSNumber(value: 0), forKey: Constants.Beta.pasteAndDeleteHistoryModifier)
        defaultValues.updateValue(NSNumber(value: false), forKey: Constants.Beta.observerScreenshot)

        AppEnvironment.current.defaults.register(defaults: defaultValues)
    }

    static func applicationSupportFolder() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        let basePath: String = paths.first ?? NSTemporaryDirectory()
        return (basePath as NSString).appendingPathComponent(Constants.Application.supportDirectoryName)
    }

    static func prepareSaveToPath(_ path: String) -> Bool {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false

        if (fileManager.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue) == false {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                logger.error("Failed to create directory at \(path): \(error.localizedDescription)")
                return false
            }
        }
        return true
    }

    static func deleteData(at path: String) {
        autoreleasepool {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: path) {
                try? fileManager.removeItem(atPath: path)
            }
        }
    }

    static func sendCustomLog(with name: String) {
        guard AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.collectCrashReport) else { return }
        logger.debug("\(name)")
    }
}
