import Foundation
import Quick
import Nimble
import RealmSwift
@testable import Clipy

class LegacyClipFolderMigrationSpec: QuickSpec {
    override class func spec() {

        var realm: Realm!
        var root: URL!
        var legacy: URL!
        var current: URL!

        func clip(_ hash: String, at path: String, contents: String? = nil) -> CPYClip {
            if let contents { FileManager.default.createFile(atPath: path, contents: Data(contents.utf8)) }
            let clip = CPYClip()
            clip.dataHash = hash
            clip.dataPath = path
            return clip
        }

        beforeEach {
            Realm.Configuration.defaultConfiguration.inMemoryIdentifier = NSUUID().uuidString
            realm = try! Realm()
            root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
            legacy = root.appendingPathComponent("ClipyDev")
            current = root.appendingPathComponent("Clipy")
            try! FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
            try! FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
        }

        afterEach {
            realm.transaction { realm.deleteAll() }
            try? FileManager.default.removeItem(at: root)
        }

        it("moves a release clip's file out of ClipyDev and points the clip at the copy") {
            let old = legacy.appendingPathComponent("old.data").path
            realm.transaction { realm.add(clip("a", at: old, contents: "pinned image")) }

            let result = LegacyClipFolderMigration.relocate(in: realm, legacyFolder: legacy.path, folder: current.path)

            let moved = current.appendingPathComponent("old.data").path
            expect(result) == LegacyClipFolderMigration.Result(moved: 1, missing: 0)
            expect(realm.object(ofType: CPYClip.self, forPrimaryKey: "a")?.dataPath) == moved
            expect(FileManager.default.contents(atPath: moved)) == Data("pinned image".utf8)
            expect(FileManager.default.fileExists(atPath: old)) == false
        }

        it("finds the file by name when the recorded path is under another home folder") {
            FileManager.default.createFile(atPath: legacy.appendingPathComponent("moved.data").path, contents: Data("x".utf8))
            realm.transaction { realm.add(clip("b", at: "/Users/someone-else/Library/Application Support/ClipyDev/moved.data")) }

            let result = LegacyClipFolderMigration.relocate(in: realm, legacyFolder: legacy.path, folder: current.path)

            expect(result.moved) == 1
            expect(realm.object(ofType: CPYClip.self, forPrimaryKey: "b")?.dataPath) == current.appendingPathComponent("moved.data").path
        }

        it("leaves clips already in its own folder alone and counts missing files") {
            let own = current.appendingPathComponent("own.data").path
            let gone = legacy.appendingPathComponent("gone.data").path
            realm.transaction { realm.add([clip("c", at: own, contents: "mine"), clip("d", at: gone)]) }

            let result = LegacyClipFolderMigration.relocate(in: realm, legacyFolder: legacy.path, folder: current.path)

            expect(result) == LegacyClipFolderMigration.Result(moved: 0, missing: 1)
            expect(realm.object(ofType: CPYClip.self, forPrimaryKey: "c")?.dataPath) == own
            expect(realm.object(ofType: CPYClip.self, forPrimaryKey: "d")?.dataPath) == gone
        }

        it("never overwrites a file of the same name in its own folder") {
            let old = legacy.appendingPathComponent("same.data").path
            let existing = current.appendingPathComponent("same.data").path
            FileManager.default.createFile(atPath: existing, contents: Data("other clip".utf8))
            realm.transaction { realm.add(clip("e", at: old, contents: "legacy clip")) }

            LegacyClipFolderMigration.relocate(in: realm, legacyFolder: legacy.path, folder: current.path)

            let newPath = realm.object(ofType: CPYClip.self, forPrimaryKey: "e")!.dataPath
            expect(newPath) != existing
            expect(FileManager.default.contents(atPath: existing)) == Data("other clip".utf8)
            expect(FileManager.default.contents(atPath: newPath)) == Data("legacy clip".utf8)
        }

        it("does nothing in the Debug build, whose own folder is ClipyDev") {
            let path = legacy.appendingPathComponent("dev.data").path
            realm.transaction { realm.add(clip("f", at: path, contents: "dev")) }

            let result = LegacyClipFolderMigration.relocate(in: realm, legacyFolder: legacy.path, folder: legacy.path)

            expect(result) == LegacyClipFolderMigration.Result()
            expect(FileManager.default.fileExists(atPath: path)) == true
        }
    }
}
