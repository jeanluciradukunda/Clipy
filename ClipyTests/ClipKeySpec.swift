import Quick
import Nimble
import RealmSwift
@testable import Clipy

class ClipKeySpec: QuickSpec {
    // swiftlint:disable:next function_body_length
    override class func spec() {

        func image(red: CGFloat) -> NSImage {
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 48, bitsPerSample: 8, samplesPerPixel: 4,
                                       hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            for col in 0..<64 {
                for row in 0..<48 {
                    rep.setColor(NSColor(deviceRed: red, green: CGFloat(col) / 64, blue: CGFloat(row) / 48, alpha: 1), atX: col, y: row)
                }
            }
            let image = NSImage(size: NSSize(width: 64, height: 48))
            image.addRepresentation(rep)
            return image
        }

        describe("CPYClipData.hash for images") {
            it("differs for two different images of the same size") {
                expect(CPYClipData(image: image(red: 0.1)).hash) != CPYClipData(image: image(red: 0.9)).hash
            }

            it("matches for the same image copied twice") {
                expect(CPYClipData(image: image(red: 0.5)).hash) == CPYClipData(image: image(red: 0.5)).hash
            }

            it("survives a round trip through the history file, as when a clip is pasted back") {
                let original = CPYClipData(image: image(red: 0.5))
                let archive = NSKeyedArchiver.archivedData(withRootObject: original)
                let restored = NSKeyedUnarchiver.unarchiveObject(with: archive) as? CPYClipData
                expect(restored?.hash) == original.hash
            }

            it("still knows the size-based key earlier releases used") {
                let data = CPYClipData(image: image(red: 0.5))
                let byteCount = image(red: 0.5).tiffRepresentation!.count
                expect(data.legacyHash) == NSPasteboard.PasteboardType.clipyTIFF.rawValue.hash ^ byteCount
            }
        }

        // Two texts NSString.hash cannot tell apart: it samples long strings rather than reading them whole.
        func collidingTexts() -> (String, String) {
            let first = "line one\nline two\nline three\nline four: password=hunter2\n" + String(repeating: "x", count: 200) + "\nend"
            return (first, first.replacingOccurrences(of: "hunter2", with: "secret7"))
        }

        func text(_ string: String) -> CPYClipData {
            let data = CPYClipData(image: NSImage())
            data.image = nil
            data.types = [.string]
            data.stringValue = string
            return data
        }

        describe("CPYClipData.hash for text and documents") {
            it("differs for two different long texts that share an NSString hash") {
                let (first, second) = collidingTexts()
                expect((first as NSString).hash) == (second as NSString).hash
                expect(text(first).hash) != text(second).hash
            }

            it("matches for the same text copied twice") {
                let (first, _) = collidingTexts()
                expect(text(first).hash) == text(first).hash
            }

            it("differs for two different PDFs of the same size") {
                let pdfA = CPYClipData(image: NSImage()), pdfB = CPYClipData(image: NSImage())
                for (data, byte) in [(pdfA, UInt8(1)), (pdfB, UInt8(2))] {
                    data.image = nil
                    data.types = [.pdf]
                    data.PDF = Data(repeating: byte, count: 512)
                }
                expect(pdfA.hash) != pdfB.hash
            }
        }

        describe("ClipService.legacyDuplicateKey") {
            var realm: Realm!
            var archivePath: String!

            beforeEach {
                realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: NSUUID().uuidString))
                archivePath = NSTemporaryDirectory() + NSUUID().uuidString + ".data"
            }

            afterEach {
                try? FileManager.default.removeItem(atPath: archivePath)
            }

            func saveLegacyClip(holding stored: CPYClipData, key: Int) {
                NSKeyedArchiver.archiveRootObject(stored, toFile: archivePath)
                let clip = CPYClip()
                clip.dataHash = "\(key)"
                clip.dataPath = archivePath
                realm.transaction { realm.add(clip) }
            }

            it("finds the same image saved under its old key") {
                let copied = CPYClipData(image: image(red: 0.3))
                saveLegacyClip(holding: CPYClipData(image: image(red: 0.3)), key: copied.legacyHash!)
                expect(ClipService.legacyDuplicateKey(for: copied, in: realm)) == "\(copied.legacyHash!)"
            }

            it("leaves a different same-size image under the old key alone") {
                let copied = CPYClipData(image: image(red: 0.3))
                saveLegacyClip(holding: CPYClipData(image: image(red: 0.7)), key: copied.legacyHash!)
                expect(ClipService.legacyDuplicateKey(for: copied, in: realm)) == nil
            }

            it("keeps the old clip's file while its record still exists, as after a failed commit") {
                let copied = CPYClipData(image: image(red: 0.3))
                saveLegacyClip(holding: copied, key: copied.legacyHash!)
                ClipService.removeReplacedLegacyFiles((archivePath, ""), key: "\(copied.legacyHash!)", in: realm)
                expect(FileManager.default.fileExists(atPath: archivePath)) == true
            }

            it("deletes the old clip's file once its record is gone") {
                let copied = CPYClipData(image: image(red: 0.3))
                saveLegacyClip(holding: copied, key: copied.legacyHash!)
                realm.transaction { realm.delete(realm.objects(CPYClip.self)) }
                ClipService.removeReplacedLegacyFiles((archivePath, ""), key: "\(copied.legacyHash!)", in: realm)
                expect(FileManager.default.fileExists(atPath: archivePath)) == false
            }

            it("finds the same text saved under its old key") {
                let (first, _) = collidingTexts()
                let copied = text(first)
                saveLegacyClip(holding: text(first), key: copied.legacyHash!)
                expect(ClipService.legacyDuplicateKey(for: copied, in: realm)) == "\(copied.legacyHash!)"
            }

            it("leaves a different text that shared the old key alone") {
                let (first, second) = collidingTexts()
                let copied = text(second)
                expect(copied.legacyHash) == text(first).legacyHash
                saveLegacyClip(holding: text(first), key: copied.legacyHash!)
                expect(ClipService.legacyDuplicateKey(for: copied, in: realm)) == nil
            }
        }
    }
}
