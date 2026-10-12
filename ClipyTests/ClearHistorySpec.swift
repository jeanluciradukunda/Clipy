import Quick
import Nimble
import RealmSwift
@testable import Clipy

class ClearHistorySpec: QuickSpec {
    override class func spec() {

        var realm: Realm!

        beforeEach {
            Realm.Configuration.defaultConfiguration.inMemoryIdentifier = NSUUID().uuidString
            realm = try! Realm()
        }

        afterEach {
            realm.transaction { realm.deleteAll() }
        }

        func clipWithFile(_ hash: String, pinned: Bool = false) -> (CPYClip, String) {
            let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("\(UUID().uuidString).data")
            FileManager.default.createFile(atPath: path, contents: Data("copied text".utf8))
            let clip = CPYClip()
            clip.dataHash = hash
            clip.dataPath = path
            clip.isPinned = pinned
            return (clip, path)
        }

        // Clears everything so the Realm ends empty: with clips left, cleanDatas() sweeps the real
        // Application Support folder against this in-memory Realm and deletes the real files
        it("deletes every cleared clip's file when the clear empties the history") {
            let defaults = UserDefaults(suiteName: "ClearHistorySpec-\(UUID().uuidString)")!
            defaults.set(true, forKey: Constants.UserDefaults.clearHistoryIncludesPinned)
            AppEnvironment.push(defaults: defaults)
            defer { AppEnvironment.popLast() }

            let (plain, plainPath) = clipWithFile("plain")
            let (pinned, pinnedPath) = clipWithFile("pinned", pinned: true)
            realm.transaction { realm.add([plain, pinned]) }

            ClipService().clearAll()

            expect(realm.objects(CPYClip.self).count) == 0
            expect(FileManager.default.fileExists(atPath: plainPath)) == false
            expect(FileManager.default.fileExists(atPath: pinnedPath)) == false
        }
    }
}
