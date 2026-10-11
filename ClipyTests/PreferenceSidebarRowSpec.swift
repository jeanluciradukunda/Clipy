import Quick
import Nimble
import SwiftUI
@testable import Clipy

class PreferenceSidebarRowSpec: QuickSpec {
    override class func spec() {

        var window: NSWindow!
        var clicks = 0

        beforeEach {
            clicks = 0
            let row = PreferenceSidebarRow(tab: .general, isSelected: false) { clicks += 1 }
                .frame(width: 136)
            let host = NSHostingView(rootView: row)
            host.frame.size = host.fittingSize
            window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.orderFrontRegardless()
            host.layoutSubtreeIfNeeded()
        }

        afterEach {
            window.close()
        }

        func click(atX offset: CGFloat) {
            guard let host = window.contentView else { return }
            let location = host.convert(NSPoint(x: offset, y: host.bounds.midY), to: nil)
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                let event = NSEvent.mouseEvent(with: type, location: location, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                               windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)
                event.map(window.sendEvent)
            }
        }

        describe("PreferenceSidebarRow") {
            it("selects the tab when its label is clicked") {
                click(atX: 50)
                expect(clicks).toEventually(equal(1))
            }

            it("selects the tab when the empty space beside the label is clicked") {
                click(atX: window.contentView!.bounds.maxX - 8)
                expect(clicks).toEventually(equal(1))
            }
        }
    }
}
