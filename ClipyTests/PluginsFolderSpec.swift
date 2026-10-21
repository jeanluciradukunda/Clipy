import Quick
import Nimble
@testable import Clipy

class PluginsFolderSpec: QuickSpec {
    override class func spec() {
        describe("PluginManager.pluginsDirectoryURL") {
            it("gives Clipy Dev its own folder, apart from the release app's ~/.clipy/plugins") {
                let url = PluginManager.pluginsDirectoryURL
                expect(url.path).to(endWith("/.clipy-dev/plugins"))
                expect(url.deletingLastPathComponent().deletingLastPathComponent().path) == NSHomeDirectory()
            }
        }
    }
}
