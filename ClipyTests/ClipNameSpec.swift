import Quick
import Nimble
import RealmSwift
@testable import Clipy

class ClipNameSpec: QuickSpec {
    override class func spec() {

        func makeClip(_ hash: String, name: String? = nil, expiresAt: Date? = nil,
                      time: Int = 0, pinned: Bool = false, dataPath: String = "") -> CPYClip {
            let clip = CPYClip()
            clip.dataHash = hash
            clip.name = name
            clip.expiresAt = expiresAt
            clip.updateTime = time
            clip.isPinned = pinned
            clip.dataPath = dataPath
            return clip
        }

        let past = Date().addingTimeInterval(-60)
        let future = Date().addingTimeInterval(3600)
        var realm: Realm!
        var service: ClipService!

        beforeEach {
            Realm.Configuration.defaultConfiguration.inMemoryIdentifier = NSUUID().uuidString
            realm = try! Realm()
            service = ClipService()
        }

        afterEach {
            realm.transaction { realm.deleteAll() }
        }

        describe("ClipService.setName") {
            it("names a clip with an expiry") {
                let clip = makeClip("a")
                realm.transaction { realm.add(clip) }

                service.setName("  github-token ", expiresAt: future, for: clip)

                expect(clip.name) == "github-token"
                expect(clip.expiresAt) == future
            }

            it("clears the name and expiry when given a blank name") {
                let clip = makeClip("a", name: "token", expiresAt: future)
                realm.transaction { realm.add(clip) }

                service.setName("   ", expiresAt: future, for: clip)

                expect(clip.name).to(beNil())
                expect(clip.expiresAt).to(beNil())
            }

            it("moves a name another clip already holds, so names stay unique") {
                let old = makeClip("old", name: "Token", expiresAt: future)
                let new = makeClip("new")
                realm.transaction { realm.add([old, new]) }

                service.setName("token", expiresAt: nil, for: new)

                expect(old.name).to(beNil())
                expect(old.expiresAt).to(beNil())
                expect(new.name) == "token"
            }
        }

        describe("CPYClip.named") {
            it("matches ignoring case and surrounding spaces") {
                realm.transaction { realm.add(makeClip("a", name: "GitHub-Token")) }

                expect(CPYClip.named(" github-token ", in: realm)?.dataHash) == "a"
            }

            it("does not return an expired clip") {
                realm.transaction { realm.add(makeClip("a", name: "token", expiresAt: past)) }

                expect(CPYClip.named("token", in: realm)).to(beNil())
            }

            it("returns nothing for a blank name") {
                realm.transaction { realm.add(makeClip("a", name: "token")) }

                expect(CPYClip.named("  ", in: realm)).to(beNil())
            }
        }

        describe("CPYClip.namedClips") {
            it("lists unexpired named clips by name") {
                realm.transaction {
                    realm.add([
                        makeClip("1", name: "zeta"),
                        makeClip("2", name: "Alpha", expiresAt: future),
                        makeClip("3", name: "gone", expiresAt: past),
                        makeClip("4")
                    ])
                }

                expect(CPYClip.namedClips(in: realm).compactMap { $0.name }) == ["Alpha", "zeta"]
            }
        }

        describe("ClipService.purgeExpired") {
            it("deletes expired clips and their data files, and keeps the rest") {
                let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("\(UUID().uuidString).data")
                FileManager.default.createFile(atPath: path, contents: Data("secret".utf8))
                realm.transaction {
                    realm.add([
                        makeClip("expired", name: "old", expiresAt: past, dataPath: path),
                        makeClip("live", name: "new", expiresAt: future),
                        makeClip("plain")
                    ])
                }

                service.purgeExpired()

                expect(realm.objects(CPYClip.self).map { $0.dataHash }.sorted()) == ["live", "plain"]
                expect(FileManager.default.fileExists(atPath: path)) == false
            }
        }

        describe("DataCleanService.overflowingClips") {
            it("never evicts named clips for space") {
                let defaults = UserDefaults(suiteName: "ClipNameSpec-\(UUID().uuidString)")!
                defaults.set(1, forKey: Constants.UserDefaults.maxHistorySize)
                AppEnvironment.push(defaults: defaults)
                defer { AppEnvironment.popLast() }

                realm.transaction {
                    realm.add([
                        makeClip("newest", time: 300),
                        makeClip("named", name: "token", time: 100),
                        makeClip("pinned", time: 50, pinned: true),
                        makeClip("oldest", time: 10)
                    ])
                }

                let evicted = DataCleanService().overflowingClips(with: realm).map { $0.dataHash }
                expect(Array(evicted)) == ["oldest"]
            }
        }
    }
}
