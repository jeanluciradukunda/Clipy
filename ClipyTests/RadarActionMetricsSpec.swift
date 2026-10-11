import Quick
import Nimble
@testable import Clipy

class RadarActionMetricsSpec: QuickSpec {
    override class func spec() {

        func count(_ event: MetricEvent) -> Int {
            return MainActor.assumeIsolated { UsageMetricsService.shared.counters[event.rawValue] ?? 0 }
        }

        func viewModel(selecting text: String) -> ClipSearchViewModel {
            return MainActor.assumeIsolated {
                let model = ClipSearchViewModel()
                model.clips = [ClipItemViewModel(id: "1", title: text, fullText: text, primaryType: NSPasteboard.PasteboardType.string.rawValue,
                                                 updateTime: Date(), isPinned: false, isColorCode: false, thumbnailKey: "", dataHash: "1")]
                model.selectedIndex = 0
                return model
            }
        }

        describe("Search panel actions") {
            it("counts a text transform") {
                let model = viewModel(selecting: "hello")
                let before = count(.textTransformed)
                MainActor.assumeIsolated { model.copyTransformed { $0.uppercased() } }
                expect(count(.textTransformed)) == before + 1
                expect(NSPasteboard.general.string(forType: .string)) == "HELLO"
            }

            it("counts JSON formatting as JSON, not as a transform") {
                let model = viewModel(selecting: "{\"a\":1}")
                let json = count(.jsonFormatted), transform = count(.textTransformed)
                MainActor.assumeIsolated { model.copyTransformed(as: .jsonFormatted) { JSONFormatter.prettyPrint($0) ?? $0 } }
                expect(count(.jsonFormatted)) == json + 1
                expect(count(.textTransformed)) == transform
            }

            it("counts a cleaned URL") {
                let model = viewModel(selecting: "x")
                let before = count(.urlCleaned)
                MainActor.assumeIsolated { model.copyCleanedURL(from: "https://example.com/page?utm_source=news&id=7") }
                expect(count(.urlCleaned)) == before + 1
                expect(NSPasteboard.general.string(forType: .string)) == "https://example.com/page?id=7"
            }

            it("does not count a URL with nothing to clean") {
                let model = viewModel(selecting: "x")
                let before = count(.urlCleaned)
                MainActor.assumeIsolated { model.copyCleanedURL(from: "https://example.com/page?id=7") }
                expect(count(.urlCleaned)) == before
            }
        }

        describe("Collect mode") {
            let queue = ClipboardQueueService.shared

            afterEach {
                queue.stopCollecting()
            }

            it("counts pasting the next queued clip") {
                queue.startCollecting()
                queue.queue = [QueuedClip(content: "one", timestamp: Date(), sourceApp: "Spec")]
                let before = count(.queueUsed)
                queue.pasteNext()
                expect(count(.queueUsed)) == before + 1
            }

            it("counts pasting the merged queue") {
                queue.startCollecting()
                queue.queue = [QueuedClip(content: "one", timestamp: Date(), sourceApp: "Spec"),
                               QueuedClip(content: "two", timestamp: Date(), sourceApp: "Spec")]
                let before = count(.queueUsed)
                queue.pasteMerged()
                expect(count(.queueUsed)) == before + 1
            }
        }
    }
}
