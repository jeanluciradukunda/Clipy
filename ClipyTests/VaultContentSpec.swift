import Quick
import Nimble
import RealmSwift
@testable import Clipy

class VaultContentSpec: QuickSpec {
    override class func spec() {

        beforeEach {
            Realm.Configuration.defaultConfiguration.inMemoryIdentifier = NSUUID().uuidString
        }

        describe("Locked vault content") {
            var vaultID = ""

            beforeEach {
                let folder = CPYFolder()
                folder.title = "Vault"
                folder.isVault = true
                let snippet = CPYSnippet()
                snippet.title = "token"
                snippet.content = "zzz-vault-content"
                folder.snippets.append(snippet)
                let realm = try! Realm()
                realm.transaction { realm.add(folder) }
                vaultID = folder.identifier
                MainActor.assumeIsolated { VaultAuthService.shared.lockAll() }
            }

            it("is not expanded when the picker opens on the vault folder") {
                let expanded: Bool = MainActor.assumeIsolated {
                    let model = SnippetPickerViewModel()
                    model.load(filterFolderID: vaultID)
                    return model.expandedFolderIDs.contains(vaultID)
                }
                expect(expanded) == false
            }

            it("does not match the editor's sidebar filter") {
                let listed: Bool = MainActor.assumeIsolated {
                    let model = SnippetsEditorViewModel()
                    model.load()
                    model.sidebarFilter = "zzz-vault"
                    return model.filteredFolders.contains { $0.id == vaultID }
                }
                expect(listed) == false
            }

            it("is not expanded by installing a template into the vault folder") {
                let expanded: Bool = MainActor.assumeIsolated {
                    let model = SnippetsEditorViewModel()
                    model.load()
                    model.selectedFolderID = vaultID
                    model.installTemplate(SnippetTemplateLibrary.templates[0])
                    return model.expandedFolderIDs.contains(vaultID) || model.selectedSnippetID != nil
                }
                expect(expanded) == false
            }

            it("counts a lock and unlock in between as no longer unlocked") {
                let (before, after): (Bool, Bool) = MainActor.assumeIsolated {
                    let service = VaultAuthService.shared
                    let original = service.evaluate
                    defer { service.evaluate = original }
                    service.evaluate = { _, done in done(true) }
                    service.authenticate(folderID: vaultID) { _ in }
                    let generation = service.lockGeneration
                    let before = service.isStillUnlocked(vaultID, since: generation)
                    service.lockAll()
                    service.authenticate(folderID: vaultID) { _ in }
                    return (before, service.isStillUnlocked(vaultID, since: generation))
                }
                expect(before) == true
                expect(after) == false
            }

            it("cannot be pasted from a menu item while locked") {
                let realm = try! Realm()
                let snippet = realm.object(ofType: CPYFolder.self, forPrimaryKey: vaultID)!.snippets[0]
                let allowed = MainActor.assumeIsolated { VaultAuthService.shared.allows(snippet) }
                expect(allowed) == false
                expect(MainActor.assumeIsolated { VaultAuthService.shared.allows(CPYSnippet()) }) == true
            }
        }
    }
}
