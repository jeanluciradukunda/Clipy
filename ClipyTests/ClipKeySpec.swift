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
        }
    }
}
