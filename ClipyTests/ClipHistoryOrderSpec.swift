import Quick
import Nimble
import RealmSwift
@testable import Clipy

class ClipHistoryOrderSpec: QuickSpec {
    override class func spec() {

        func clip(_ hash: String, time: Int, pinned: Bool = false) -> CPYClip {
            let clip = CPYClip()
            clip.dataHash = hash
            clip.updateTime = time
            clip.isPinned = pinned
            return clip
        }

        describe("CPYClip.historyOrder") {
            it("lists the newest clip first, after pinned clips") {
                let realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: NSUUID().uuidString))
                realm.transaction {
                    realm.add([clip("old", time: 100), clip("new", time: 300), clip("pinned", time: 50, pinned: true), clip("mid", time: 200)])
                }

                expect(CPYClip.historyOrder(in: realm).map { $0.dataHash }) == ["pinned", "new", "mid", "old"]
            }
        }

        describe("CPYClip.updateTime") {
            it("moves a copied-again clip to the top when sorting by Last Used") {
                expect(CPYClip.updateTime(existing: 100, now: 500, reorderAfterPasting: true)) == 500
            }

            it("keeps a copied-again clip where it was when sorting by Date Created") {
                expect(CPYClip.updateTime(existing: 100, now: 500, reorderAfterPasting: false)) == 100
            }

            it("stamps a new clip with the current time either way") {
                expect(CPYClip.updateTime(existing: nil, now: 500, reorderAfterPasting: true)) == 500
                expect(CPYClip.updateTime(existing: nil, now: 500, reorderAfterPasting: false)) == 500
            }
        }
    }
}
