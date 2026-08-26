import Quick
import Nimble
@testable import Clipy

class ClipFilterSpec: QuickSpec {
    override class func spec() {

        describe("ClipFilter chip order") {
            it("matches the order shown in the panel's filter bar") {
                expect(ClipFilter.allCases) == [.all, .text, .images, .links, .files, .pinned, .queue]
            }
        }

        describe("ClipFilter.next") {
            it("advances one step through the chips") {
                expect(ClipFilter.all.next) == ClipFilter.text
                expect(ClipFilter.text.next) == ClipFilter.images
                expect(ClipFilter.images.next) == ClipFilter.links
                expect(ClipFilter.links.next) == ClipFilter.files
                expect(ClipFilter.files.next) == ClipFilter.pinned
                expect(ClipFilter.pinned.next) == ClipFilter.queue
            }

            it("wraps from the last chip back to All") {
                expect(ClipFilter.queue.next) == ClipFilter.all
            }

            it("returns to the starting filter after a full lap") {
                var filter = ClipFilter.all
                for _ in 0..<ClipFilter.allCases.count {
                    filter = filter.next
                }
                expect(filter) == ClipFilter.all
            }

            it("visits every filter exactly once in a lap") {
                var visited = [ClipFilter]()
                var filter = ClipFilter.all
                for _ in 0..<ClipFilter.allCases.count {
                    visited.append(filter)
                    filter = filter.next
                }
                expect(Set(visited).count) == ClipFilter.allCases.count
            }
        }
    }
}
