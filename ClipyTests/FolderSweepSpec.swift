import Quick
import Nimble
@testable import Clipy

class FolderSweepSpec: QuickSpec {
    override class func spec() {

        describe("DataCleanService.orphanedDataFiles") {
            var folder: String!

            beforeEach {
                let longAgo = Date(timeIntervalSinceNow: -3600)
                folder = NSTemporaryDirectory() + "FolderSweepSpec-" + UUID().uuidString
                try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
                for (name, date) in [("kept.data", longAgo), ("orphan.data", longAgo), ("just-saved.data", Date()), ("notes.txt", longAgo)] {
                    FileManager.default.createFile(atPath: "\(folder!)/\(name)", contents: Data("x".utf8),
                                                   attributes: [.modificationDate: date])
                }
                try? FileManager.default.createDirectory(atPath: "\(folder!)/thumbnails.data", withIntermediateDirectories: true)
            }

            afterEach {
                try? FileManager.default.removeItem(atPath: folder)
            }

            it("selects only old, regular .data files that no clip names") {
                let names = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
                let orphans = DataCleanService.orphanedDataFiles(in: folder, names: names, keeping: ["kept.data"], now: Date())
                expect(orphans) == ["\(folder!)/orphan.data"]
            }
        }
    }
}
