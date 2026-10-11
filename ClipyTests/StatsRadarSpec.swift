import Quick
import Nimble
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
    }
}
