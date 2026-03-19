//
//  ClipboardQueueService.swift
//
//  Clipy
//
//  Collect Mode: gather multiple clipboard items, then paste them
//  all at once — merged or sequentially.
//

import Foundation
import Cocoa
import Combine
import os.log

private let logger = Logger(subsystem: "com.clipy-app.Clipy", category: "Queue")

// MARK: - Queued Item
struct QueuedClip: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let timestamp: Date
    let sourceApp: String

    static func == (lhs: QueuedClip, rhs: QueuedClip) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Merge Separator
enum MergeSeparator: String, CaseIterable, Identifiable {
    case newline = "New Line"
    case comma = "Comma"
    case tab = "Tab"
    case space = "Space"
    case doubleNewline = "Blank Line"
    case custom = "Custom"

    var id: String { rawValue }

    var value: String {
        switch self {
        case .newline: return "\n"
        case .comma: return ", "
        case .tab: return "\t"
        case .space: return " "
        case .doubleNewline: return "\n\n"
        case .custom: return ""
        }
    }

    var icon: String {
        switch self {
        case .newline: return "return"
        case .comma: return "comma"
        case .tab: return "arrow.right.to.line"
        case .space: return "space"
        case .doubleNewline: return "text.line.first.and.arrowtriangle.forward"
        case .custom: return "pencil"
        }
    }
}

// MARK: - Queue Service
final class ClipboardQueueService: ObservableObject {
    static let shared = ClipboardQueueService()

    static let maxQueueSize = 500

    @Published var isCollecting = false
    @Published var queue = [QueuedClip]()
    @Published var separator: MergeSeparator = .newline

    /// Sequential paste index — tracks which item to paste next
    private var sequentialIndex = 0
    private var monitorTask: Task<Void, Never>?

    private init() {}

    // MARK: - Toggle

    func toggle() {
        if isCollecting {
            stopCollecting()
        } else {
            startCollecting()
        }
    }

    func startCollecting() {
        guard !isCollecting else { return }
        queue.removeAll()
        sequentialIndex = 0
        isCollecting = true
        startMonitoring()
        logger.info("Collect mode started")
    }

    func stopCollecting() {
        isCollecting = false
        monitorTask?.cancel()
        monitorTask = nil
        logger.info("Collect mode stopped with \(self.queue.count) items")
    }

    // MARK: - Monitor clipboard during collection

    private func startMonitoring() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            var lastCount = NSPasteboard.general.changeCount
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self = self, self.isCollecting else { break }
                let currentCount = NSPasteboard.general.changeCount
                if currentCount != lastCount {
                    lastCount = currentCount
                    self.captureCurrentClipboard()
                }
            }
        }
    }

    private func captureCurrentClipboard() {
        let pasteboard = NSPasteboard.general
        guard let string = pasteboard.string(forType: .string), !string.isEmpty else { return }

        // Don't add duplicates of the last item
        if let last = queue.last, last.content == string { return }

        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        let item = QueuedClip(content: string, timestamp: Date(), sourceApp: appName)
        queue.append(item)
        // Evict oldest items if queue exceeds max size
        if queue.count > Self.maxQueueSize {
            queue.removeFirst(queue.count - Self.maxQueueSize)
        }
        logger.info("Queued item #\(self.queue.count) from \(appName)")
    }

    // MARK: - Paste

    /// Paste all items merged with the selected separator
    func pasteMerged(customSeparator: String? = nil) {
        guard !queue.isEmpty else { return }
        let sep = separator == .custom ? (customSeparator ?? "\n") : separator.value
        let merged = queue.map(\.content).joined(separator: sep)

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(merged, forType: .string)

        // Increment ClipService's change count so it doesn't re-record our paste
        AppEnvironment.current.clipService.incrementChangeCount()

        stopCollecting()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AppEnvironment.current.pasteService.paste()
        }
    }

    /// Paste the next item in the queue sequentially
    func pasteNext() {
        guard !queue.isEmpty else { return }
        guard sequentialIndex < queue.count else {
            // All items pasted — stop collecting
            stopCollecting()
            return
        }

        let item = queue[sequentialIndex]
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
        sequentialIndex += 1

        // Increment ClipService's change count so it doesn't re-record our paste
        AppEnvironment.current.clipService.incrementChangeCount()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AppEnvironment.current.pasteService.paste()
        }

        if sequentialIndex >= queue.count {
            stopCollecting()
        }
    }

    // MARK: - Queue Management

    func removeItem(_ item: QueuedClip) {
        queue.removeAll { $0.id == item.id }
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
    }

    func clearQueue() {
        queue.removeAll()
        sequentialIndex = 0
        stopCollecting()
    }

    var mergedPreview: String {
        let sep = separator.value
        return queue.map(\.content).joined(separator: sep)
    }

    var itemCount: Int { queue.count }
    var hasItems: Bool { !queue.isEmpty }
    var remainingSequential: Int { max(0, queue.count - sequentialIndex) }
}
