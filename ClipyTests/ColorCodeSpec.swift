import Quick
import Nimble
@testable import Clipy

class ColorCodeSpec: QuickSpec {
    override class func spec() {

        describe("NSColor(hexString:)") {
            func components(_ hex: String) -> [CGFloat]? {
                guard let color = NSColor(hexString: hex) else { return nil }
                return [color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent]
            }

            it("reads every supported length, with or without #") {
                expect(components("#fff")) == [1, 1, 1, 1]
                expect(components("f008")) == [1, 0, 0, CGFloat(0x88) / 255]
                expect(components("#336699")) == [CGFloat(0x33) / 255, CGFloat(0x66) / 255, CGFloat(0x99) / 255, 1]
                expect(components("00ff0080")) == [0, 1, 0, CGFloat(0x80) / 255]
            }

            it("rejects other lengths and non-hex text") {
                for text in ["", "#", "ff", "12345", "1234567", "ggg", "##fff", " fff", "0x123"] {
                    expect(components(text)).to(beNil(), description: text)
                }
            }

            it("keeps accepting a signed value, as the SwiftHEXColors pod did") {
                expect(components("+fff")).toNot(beNil())
                expect(components("-ff")).toNot(beNil())
            }
        }
    }
}
