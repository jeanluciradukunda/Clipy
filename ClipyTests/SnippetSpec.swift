import Quick
import Nimble
import RealmSwift
@testable import Clipy

class SnippetSpec: QuickSpec {
    override class func spec() {

        beforeEach {
            Realm.Configuration.defaultConfiguration.inMemoryIdentifier = NSUUID().uuidString
        }

        describe("Epoch to Date template") {
            func run(clipboard: String, in dir: URL) -> String {
                let template = SnippetTemplateLibrary.templates.first { $0.name == "Epoch to Date" }!
                let process = Process()
                process.executableURL = URL(fileURLWithPath: template.shell)
                process.arguments = ["-c", template.content]
                process.currentDirectoryURL = dir
                process.environment = ["PATH": "/usr/bin:/bin", "CLIPBOARD": clipboard, "TZ": "UTC"]
                let pipe = Pipe()
                process.standardOutput = pipe
                try! process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            it("treats clipboard text as data, never as a shell expression") {
                let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: dir) }

                let output = run(clipboard: "a[$(touch marker)]", in: dir)

                expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("marker").path)) == false
                expect(output) == "[Invalid timestamp]"
            }

            it("still converts second and millisecond timestamps") {
                let dir = FileManager.default.temporaryDirectory
                expect(run(clipboard: "1700000000", in: dir)) == "2023-11-14 22:13:20 UTC"
                expect(run(clipboard: "1700000000000", in: dir)) == "2023-11-14 22:13:20 UTC"
                expect(run(clipboard: " 1700000000\n", in: dir)) == "2023-11-14 22:13:20 UTC"
            }
        }

        describe("Sync database") {

            it("Merge snippet") {
                let snippet = CPYSnippet()
                let realm = try! Realm()
                realm.transaction { realm.add(snippet) }

                let snippet2 = CPYSnippet()
                snippet2.identifier = snippet.identifier
                snippet2.index = 100
                snippet2.title = "title"
                snippet2.content = "content"
                snippet2.merge()
                expect(snippet2.realm).to(beNil())

                expect(snippet.index) == snippet2.index
                expect(snippet.title) == snippet2.title
                expect(snippet.content) == snippet2.content
            }

            it("Remove snippet") {
                let realm = try! Realm()
                expect(realm.objects(CPYSnippet.self).count) == 0

                let snippet = CPYSnippet()
                realm.transaction { realm.add(snippet) }

                expect(realm.objects(CPYSnippet.self).count) == 1

                let snippet2 = CPYSnippet()
                snippet2.identifier = snippet.identifier
                snippet2.remove()

                expect(realm.objects(CPYSnippet.self).count) == 0
            }

            afterEach {
                let realm = try! Realm()
                realm.transaction { realm.deleteAll() }
            }

        }

    }
}
