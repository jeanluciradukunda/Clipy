import AppKit
import Quick
import Nimble
import RealmSwift
@testable import Clipy

// swiftlint:disable function_body_length
class FolderSpec: QuickSpec {
    override class func spec() {

        beforeEach {
            Realm.Configuration.defaultConfiguration.inMemoryIdentifier = NSUUID().uuidString
        }

        describe("Create new") {

            it("deep copy object") {
                // Save Value
                let savedFolder = CPYFolder()
                savedFolder.index = 100
                savedFolder.title = "saved realm folder"

                let savedSnippet = CPYSnippet()
                savedSnippet.index = 10
                savedSnippet.title = "saved realm snippet"
                savedSnippet.content = "content"
                savedFolder.snippets.append(savedSnippet)

                let realm = try! Realm()
                realm.transaction { realm.add(savedFolder) }

                // Saved in Realm
                expect(savedFolder.realm).toNot(beNil())
                expect(savedSnippet.realm).toNot(beNil())

                // Deep copy
                let folder = savedFolder.deepCopy()
                expect(folder.realm).to(beNil())
                expect(folder.index) == savedFolder.index
                expect(folder.enable) == savedFolder.enable
                expect(folder.title) == savedFolder.title
                expect(folder.identifier) == savedFolder.identifier
                expect(folder.snippets.count) == 1

                let snippet = folder.snippets.first!
                expect(snippet.realm).to(beNil())
                expect(snippet.index) == savedSnippet.index
                expect(snippet.enable) == savedSnippet.enable
                expect(snippet.title) == savedSnippet.title
                expect(snippet.content) == savedSnippet.content
                expect(snippet.identifier) == savedSnippet.identifier
            }

            it("Create folder") {
                let folder = CPYFolder.create()
                expect(folder.title) == "untitled folder"
                expect(folder.index) == 0

                let realm = try! Realm()
                realm.transaction { realm.add(folder) }

                let folder2 = CPYFolder.create()
                expect(folder2.index) == 1
            }

            it("Create snippet") {
                let folder = CPYFolder()
                let snippet = folder.createSnippet()

                expect(snippet.title) == "untitled snippet"
                expect(snippet.index) == 0

                folder.snippets.append(snippet)

                let snippet2 = folder.createSnippet()
                expect(snippet2.index) == 1
            }

            afterEach {
                let realm = try! Realm()
                realm.transaction { realm.deleteAll() }
            }

        }

        describe("Sync database") {

            it("Merge snippet") {
                let folder = CPYFolder()
                let realm = try! Realm()
                realm.transaction { realm.add(folder) }
                let copyFolder = folder.deepCopy()

                let snippet = CPYSnippet()
                let snippet2 = CPYSnippet()
                copyFolder.mergeSnippet(snippet)
                copyFolder.mergeSnippet(snippet2)

                expect(snippet.realm).to(beNil())
                expect(snippet2.realm).to(beNil())
                expect(folder.snippets.count) == 2

                let savedSnippet = folder.snippets.first!
                let savedSnippet2 = folder.snippets[1]
                expect(savedSnippet.identifier) == snippet.identifier
                expect(savedSnippet2.identifier) == snippet2.identifier
            }

            it("Insert snippet") {
                let folder = CPYFolder()
                let realm = try! Realm()
                realm.transaction { realm.add(folder) }
                let copyFolder = folder.deepCopy()

                let snippet = CPYSnippet()
                // Don't insert non saved snippt
                copyFolder.insertSnippet(snippet, index: 0)
                expect(folder.snippets.count) == 0

                realm.transaction { realm.add(snippet) }

                // Can insert saved snippet
                copyFolder.insertSnippet(snippet, index: 0)
                expect(folder.snippets.count) == 1
            }

            it("Remove snippet") {
                let folder = CPYFolder()
                let snippet = CPYSnippet()
                folder.snippets.append(snippet)
                let realm = try! Realm()
                realm.transaction { realm.add(folder) }

                expect(folder.snippets.count) == 1

                let copyFolder = folder.deepCopy()
                copyFolder.removeSnippet(snippet)

                expect(folder.snippets.count) == 0
            }

            it("Merge folder") {
                let realm = try! Realm()
                expect(realm.objects(CPYFolder.self).count) == 0

                let folder = CPYFolder()
                folder.index = 100
                folder.title = "title"
                folder.enable = false
                folder.merge()
                expect(folder.realm).to(beNil())
                expect(realm.objects(CPYFolder.self).count) == 1

                let savedFolder = realm.object(ofType: CPYFolder.self, forPrimaryKey: folder.identifier)
                expect(savedFolder).toNot(beNil())
                expect(savedFolder?.index) == folder.index
                expect(savedFolder?.title) == folder.title
                expect(savedFolder?.enable) == folder.enable

                folder.index = 1
                folder.title = "change title"
                folder.enable = true
                folder.merge()
                expect(realm.objects(CPYFolder.self).count) == 1

                expect(savedFolder?.index) == folder.index
                expect(savedFolder?.title) == folder.title
                expect(savedFolder?.enable) == folder.enable
            }

            it("Remove folder") {
                let folder = CPYFolder()
                let snippet = CPYSnippet()
                folder.snippets.append(snippet)
                let realm = try! Realm()
                realm.transaction { realm.add(folder) }

                expect(realm.objects(CPYFolder.self).count) == 1
                expect(realm.objects(CPYSnippet.self).count) == 1

                let copyFolder = folder.deepCopy()
                expect(copyFolder.realm).to(beNil())
                copyFolder.remove()

                expect(realm.objects(CPYFolder.self).count) == 0
                expect(realm.objects(CPYSnippet.self).count) == 0
            }

            afterEach {
                let realm = try! Realm()
                realm.transaction { realm.deleteAll() }
            }

        }

        describe("Rearrange Index") {

            it("Rearrange folder index") {
                let folder = CPYFolder()
                folder.index = 100
                let folder2 = CPYFolder()
                folder2.index = 10

                let folders = [folder, folder2]
                let realm = try! Realm()
                realm.transaction { realm.add(folders) }

                let copyFolder = folder.deepCopy()
                let copyFolder2 = folder2.deepCopy()

                CPYFolder.rearrangesIndex([copyFolder, copyFolder2])

                expect(copyFolder.index) == 0
                expect(copyFolder2.index) == 1
                expect(folder.index) == 0
                expect(folder2.index) == 1
            }

            it("Rearrange snippet index") {
                let folder = CPYFolder()
                let snippet = CPYSnippet()
                snippet.index = 10
                let snippet2 = CPYSnippet()
                snippet2.index = 100
                folder.snippets.append(snippet)
                folder.snippets.append(snippet2)
                let realm = try! Realm()
                realm.transaction { realm.add(folder) }

                let copyFolder = folder.deepCopy()
                copyFolder.rearrangesSnippetIndex()

                let copySnippet = copyFolder.snippets.first!
                let copySnippet2 = copyFolder.snippets[1]
                expect(copySnippet.index) == 0
                expect(copySnippet2.index) == 1
                expect(snippet.index) == 0
                expect(snippet2.index) == 1
            }

            afterEach {
                let realm = try! Realm()
                realm.transaction { realm.deleteAll() }
            }

        }

        describe("Removing vault protection") {
            var original: ((String, @escaping (Bool) -> Void) -> Void)!

            beforeEach {
                MainActor.assumeIsolated {
                    original = VaultAuthService.shared.evaluate
                    VaultAuthService.shared.lockAll()
                }
            }

            afterEach {
                MainActor.assumeIsolated {
                    VaultAuthService.shared.evaluate = original
                    VaultAuthService.shared.lockAll()
                }
            }

            func vaultFolder() -> CPYFolder {
                let folder = CPYFolder()
                folder.title = "Vault"
                folder.isVault = true
                let realm = try! Realm()
                realm.transaction { realm.add(folder) }
                return folder
            }

            it("keeps the folder a vault when authentication fails") {
                let folder = vaultFolder()
                MainActor.assumeIsolated {
                    VaultAuthService.shared.evaluate = { _, done in done(false) }
                    SnippetsEditorViewModel().toggleVault(folder.identifier)
                }
                expect(folder.isVault) == true
            }

            it("keeps protection when the fresh prompt is refused for an unlocked folder") {
                let folder = vaultFolder()
                MainActor.assumeIsolated {
                    VaultAuthService.shared.evaluate = { _, done in done(true) }
                    VaultAuthService.shared.authenticate(folderID: folder.identifier) { _ in }
                    VaultAuthService.shared.evaluate = { _, done in done(false) }
                    SnippetsEditorViewModel().toggleVault(folder.identifier)
                }
                expect(folder.isVault) == true
            }

            it("asks again even when the folder was unlocked earlier") {
                let folder = vaultFolder()
                var prompts = 0
                MainActor.assumeIsolated {
                    VaultAuthService.shared.evaluate = { _, done in
                        prompts += 1
                        done(true)
                    }
                    VaultAuthService.shared.authenticate(folderID: folder.identifier) { _ in }
                    SnippetsEditorViewModel().toggleVault(folder.identifier)
                }
                expect(prompts) == 2
                expect(folder.isVault) == false
            }
        }
        describe("Vault unlock lifetime") {
            var original: ((String, @escaping (Bool) -> Void) -> Void)!

            beforeEach {
                MainActor.assumeIsolated {
                    original = VaultAuthService.shared.evaluate
                    VaultAuthService.shared.evaluate = { _, done in done(true) }
                    VaultAuthService.shared.lockAll()
                }
            }

            afterEach {
                MainActor.assumeIsolated {
                    VaultAuthService.shared.evaluate = original
                    VaultAuthService.shared.lockAll()
                }
            }

            it("locks every vault when the Mac goes to sleep") {
                let unlocked = { MainActor.assumeIsolated { VaultAuthService.shared.isUnlocked("vault-1") } }
                MainActor.assumeIsolated { VaultAuthService.shared.authenticate(folderID: "vault-1") { _ in } }
                expect(unlocked()) == true

                NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)

                expect(unlocked()).toEventually(beFalse())
            }

            it("locks a vault folder collapsed from the keyboard") {
                let folder = CPYFolder()
                folder.isVault = true
                let realm = try! Realm()
                realm.transaction { realm.add(folder) }

                let stillUnlocked: Bool = MainActor.assumeIsolated {
                    let model = SnippetsEditorViewModel()
                    model.load()
                    VaultAuthService.shared.authenticate(folderID: folder.identifier) { _ in }
                    model.selectedFolderID = folder.identifier
                    model.selectedSnippetID = nil
                    model.expandedFolderIDs.insert(folder.identifier)
                    model.collapseSelected()
                    return VaultAuthService.shared.isUnlocked(folder.identifier)
                }
                expect(stillUnlocked) == false
            }

            it("closes an open vault snippet in the editor when vaults lock") {
                let folder = CPYFolder()
                folder.isVault = true
                let snippet = CPYSnippet()
                snippet.content = "vault text"
                folder.snippets.append(snippet)
                let realm = try! Realm()
                realm.transaction { realm.add(folder) }

                let (expanded, selected): (Bool, String?) = MainActor.assumeIsolated {
                    let model = SnippetsEditorViewModel()
                    model.load()
                    VaultAuthService.shared.authenticate(folderID: folder.identifier) { _ in }
                    model.expandedFolderIDs.insert(folder.identifier)
                    model.selectSnippet(model.folders.first { $0.id == folder.identifier }!.snippets[0])
                    VaultAuthService.shared.lockAll()
                    return (model.expandedFolderIDs.contains(folder.identifier), model.selectedSnippetID)
                }
                expect(expanded) == false
                expect(selected).to(beNil())
            }

            it("collapses a vault and clears its selected snippet in the picker when vaults lock") {
                let folder = CPYFolder()
                folder.isVault = true
                let snippet = CPYSnippet()
                snippet.content = "vault text"
                folder.snippets.append(snippet)
                let realm = try! Realm()
                realm.transaction { realm.add(folder) }

                let (expanded, selected): (Bool, String) = MainActor.assumeIsolated {
                    let model = SnippetPickerViewModel()
                    model.load()
                    VaultAuthService.shared.authenticate(folderID: folder.identifier) { _ in }
                    model.expandedFolderIDs.insert(folder.identifier)
                    model.selectedID = snippet.identifier
                    VaultAuthService.shared.lockAll()
                    return (model.expandedFolderIDs.contains(folder.identifier), model.selectedID)
                }
                expect(expanded) == false
                expect(selected) != snippet.identifier
            }

            it("ignores an authentication that finishes after a lock") {
                var pending: ((Bool) -> Void)?
                let unlocked: Bool = MainActor.assumeIsolated {
                    VaultAuthService.shared.evaluate = { _, done in pending = done }
                    VaultAuthService.shared.authenticate(folderID: "vault-2") { _ in }
                    VaultAuthService.shared.lockAll()
                    pending?(true)
                    return VaultAuthService.shared.isUnlocked("vault-2")
                }
                expect(unlocked) == false
            }
        }
    }
}
