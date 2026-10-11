import Quick
import Nimble
import RealmSwift
@testable import Clipy

class ClipKeySpec: QuickSpec {
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

            it("ignores clips without an image") {
                let text = CPYClipData(image: image(red: 0.3))
                text.image = nil
                text.stringValue = "hello"
                expect(ClipService.legacyDuplicateKey(for: text, in: realm)) == nil
            }
        }
    }
}
