//
//  UsageMetricsService.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//
//  Local-only usage metrics tracker.
//

import Foundation
import SwiftUI

// MARK: - MetricEvent
enum MetricEvent: String, CaseIterable, Codable {
    case clipsCopied
    case pasteFromPanel
    case pasteFromMenu
    case pasteFromHotkey
    case pastePlainText
    case searchPerformed
    case ocrUsed
    case pinToggled
    case shareUsed
    case queueUsed
    case vaultUnlocked
    case snippetPasted
    case urlCleaned
    case jsonFormatted
    case textTransformed
}

// MARK: - UsageMetrics
struct UsageMetrics: Codable {
    var counters: [String: Int] = [:]
    var dailyActivity: [String: Int] = [:]
    var hourlyHistogram: [Int] = Array(repeating: 0, count: 24)
    var filterUsage: [String: Int] = [:]

    static let empty = UsageMetrics()
}

// MARK: - UsageMetricsService
@MainActor
final class UsageMetricsService: ObservableObject {

    static let shared = UsageMetricsService()

    private static let defaultsKey = "kCPYUsageMetrics"

    // MARK: - Published Properties
    @Published private(set) var counters: [String: Int] = [:]
    @Published private(set) var dailyActivity: [String: Int] = [:]
    @Published private(set) var hourlyHistogram: [Int] = Array(repeating: 0, count: 24)
    @Published private(set) var filterUsage: [String: Int] = [:]

    // MARK: - Private
    private let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    private let calendar = Calendar.current
    private var saveTimer: Timer?
    private var needsSave = false
    private let saveInterval: TimeInterval = 5.0  // Save every 5 seconds

    // MARK: - Init
    private init() {
        load()
        setupSaveTimer()
        setupAppLifecycleObservers()
    }

    deinit {
        saveTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Tracking

    func track(_ event: MetricEvent) {
        counters[event.rawValue, default: 0] += 1

        let now = Date()
        let dayKey = dateFormatter.string(from: now)
        dailyActivity[dayKey, default: 0] += 1

        let hour = calendar.component(.hour, from: now)
        hourlyHistogram[hour] += 1

        markNeedsSave()
    }

    func trackFilterUsage(_ filter: String) {
        filterUsage[filter, default: 0] += 1
        markNeedsSave()
    }

    // MARK: - Export

    func exportJSON() -> Data? {
        let metrics = UsageMetrics(
            counters: counters,
            dailyActivity: dailyActivity,
            hourlyHistogram: hourlyHistogram,
            filterUsage: filterUsage
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(metrics)
    }

    // MARK: - Reset

    func reset() {
        counters = [:]
        dailyActivity = [:]
        hourlyHistogram = Array(repeating: 0, count: 24)
        filterUsage = [:]
        saveImmediately()
    }

    // MARK: - Persistence

    private func markNeedsSave() {
        needsSave = true
    }

    private func saveIfNeeded() {
        guard needsSave else { return }
        saveImmediately()
    }

    func saveImmediately() {
        needsSave = false
        let metrics = UsageMetrics(
            counters: counters,
            dailyActivity: dailyActivity,
            hourlyHistogram: hourlyHistogram,
            filterUsage: filterUsage
        )
        if let data = try? JSONEncoder().encode(metrics) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let metrics = try? JSONDecoder().decode(UsageMetrics.self, from: data) else {
            return
        }
        counters = metrics.counters
        dailyActivity = metrics.dailyActivity
        hourlyHistogram = metrics.hourlyHistogram.count == 24
            ? metrics.hourlyHistogram
            : Array(repeating: 0, count: 24)
        filterUsage = metrics.filterUsage
    }

    // MARK: - Timer & Lifecycle

    private func setupSaveTimer() {
        saveTimer = Timer.scheduledTimer(withTimeInterval: saveInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.saveIfNeeded()
            }
        }
    }

    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: NSApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc private func appWillResignActive() {
        saveIfNeeded()
    }

    @objc private func appWillTerminate() {
        saveImmediately()
    }
}
