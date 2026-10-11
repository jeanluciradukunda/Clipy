import Quick
import Nimble
import RealmSwift
@testable import Clipy

class StatsRadarSpec: QuickSpec {
    override class func spec() {

        func value(_ label: String, in counters: [String: Int]) -> Double? {
            return StatsForNerdsView.radarValues(counters: counters).first { $0.label == label }?.value
        }

        describe("StatsForNerdsView.radarValues") {
            it("scales against the busiest radar feature, ignoring counters the radar does not show") {
                let counters = ["clipsCopied": 6000, "searchPerformed": 40, "pinToggled": 10]
                expect(value("Search", in: counters)) == 1
                expect(value("Pin", in: counters)) == 0.25
            }

            it("counts pastes from the panel, the menu and a hotkey as Paste") {
                let counters = ["pasteFromPanel": 10, "pasteFromMenu": 20, "pasteFromHotkey": 30, "searchPerformed": 15]
                expect(value("Paste", in: counters)) == 1
                expect(value("Search", in: counters)) == 0.25
            }

            it("is all zeros with no activity") {
                expect(StatsForNerdsView.radarValues(counters: [:]).map { $0.value }) == Array(repeating: 0, count: 12)
            }
        }

        describe("Pasting from the history menu") {
            let metricsKey = "kCPYUsageMetrics"
            var savedMetrics: Data?

            beforeEach {
                savedMetrics = UserDefaults.standard.data(forKey: metricsKey)
                Realm.Configuration.defaultConfiguration.inMemoryIdentifier = NSUUID().uuidString
            }

            afterEach {
                if let savedMetrics = savedMetrics {
                    UserDefaults.standard.set(savedMetrics, forKey: metricsKey)
                } else {
                    UserDefaults.standard.removeObject(forKey: metricsKey)
                }
            }

            it("counts towards the radar's Paste axis") {
                let clip = CPYClip()
                clip.dataHash = NSUUID().uuidString
                clip.dataPath = "/nonexistent/\(clip.dataHash).data"
                let realm = try! Realm()
                realm.transaction { realm.add(clip) }
                let item = NSMenuItem()
                item.representedObject = clip.dataHash
                let before = UsageMetricsService.shared.counters["pasteFromMenu"] ?? 0

                AppDelegate().selectClipMenuItem(item)

                expect(UsageMetricsService.shared.counters["pasteFromMenu"]) == before + 1
                let paste = StatsForNerdsView.radarValues(counters: UsageMetricsService.shared.counters).first { $0.label == "Paste" }
                expect(paste?.value ?? 0) > 0
            }
        }
    }
}
