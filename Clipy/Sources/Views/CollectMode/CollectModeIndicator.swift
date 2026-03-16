//
//  CollectModeIndicator.swift
//
//  Clipy Dev
//
//  Floating pill indicator for Collect Mode.
//

import SwiftUI
import Combine

// MARK: - Indicator View
struct CollectModeIndicatorView: View {
    @ObservedObject var queue = ClipboardQueueService.shared

    var body: some View {
        HStack(spacing: 8) {
            // Pulsing dot
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .shadow(color: .red.opacity(0.6), radius: 4)

            Text("Collecting")
                .font(.system(size: 11, weight: .semibold))

            Text("\(queue.itemCount)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.white.opacity(0.15))
                .clipShape(Capsule())

            Divider()
                .frame(height: 14)
                .opacity(0.3)

            Button {
                queue.pasteMerged()
                CollectModeIndicatorController.shared.dismiss()
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Paste All Merged")

            Button {
                queue.pasteNext()
                if !queue.isCollecting {
                    CollectModeIndicatorController.shared.dismiss()
                }
            } label: {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Paste Next")

            Button {
                queue.clearQueue()
                CollectModeIndicatorController.shared.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Stop & Clear")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }
}

// MARK: - Indicator Window Controller
class CollectModeIndicatorController {
    static let shared = CollectModeIndicatorController()

    private var panel: NSPanel?
    private var cancellable: AnyCancellable?

    private init() {
        // Auto-dismiss when collecting stops
        cancellable = ClipboardQueueService.shared.$isCollecting
            .receive(on: DispatchQueue.main)
            .sink { [weak self] collecting in
                if collecting {
                    self?.show()
                } else {
                    self?.dismiss()
                }
            }
    }

    func show() {
        if panel != nil { return }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 40),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false

        let hostView = NSHostingView(rootView: CollectModeIndicatorView())
        hostView.frame = NSRect(x: 0, y: 0, width: 280, height: 40)
        panel.contentView = hostView

        // Position at top-center of the active screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let originX = screenFrame.midX - 140
            let originY = screenFrame.maxY - 60
            panel.setFrameOrigin(NSPoint(x: originX, y: originY))
        }

        panel.orderFrontRegardless()
        self.panel = panel
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}
