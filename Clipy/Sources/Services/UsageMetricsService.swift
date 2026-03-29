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
    private var needsSave = false
    private var saveWorkItem: DispatchWorkItem?
    private let saveQueue = DispatchQueue(label: "com.clipy.UsageMetricsService.saveQueue")

    // MARK: - Init
    private init() {
        load()
        // Schedule periodic save in case events keep firing (safety net)
        schedulePeriodicSave()
    }

    deinit {
        saveWorkItem?.cancel()
    }

    // MARK: - Tracking

    func track(_ event: MetricEvent) {
        counters[event.rawValue, default: 0] += 1

        let now = Date()
        let dayKey = dateFormatter.string(from: now)
        dailyActivity[dayKey, default: 0] += 1

        let hour = calendar.component(.hour, from: now)
        hourlyHistogram[hour] += 1

        scheduleDelayedSave()
    }

    func trackFilterUsage(_ filter: String) {
        filterUsage[filter, default: 0] += 1
        scheduleDelayedSave()
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
        // Cancel any pending save to avoid writing old data
        saveWorkItem?.cancel()
        saveWorkItem = nil
        needsSave = false
        save()
    }

    // MARK: - Persistence

    private func save() {
        let metrics = UsageMetrics(
            counters: counters,
            dailyActivity: dailyActivity,
            hourlyHistogram: hourlyHistogram,
            filterUsage: filterUsage
        )
        if let data = try? JSONEncoder().encode(metrics) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
        needsSave = false
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

    // MARK: - Batch Scheduling

    private func scheduleDelayedSave() {
        needsSave = true
        saveQueue.async { [weak self] in
            guard let self = self else { return }
            // Cancel any pending work item
            self.saveWorkItem?.cancel()
            // Create a new work item
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                if self.needsSave {
                    self.save()
                }
            }
            self.saveWorkItem = workItem
            // Schedule the work item to run after 2 seconds
            self.saveQueue.asyncAfter(deadline: .now() + 2.0, execute: workItem)
        }
    }

    private func schedulePeriodicSave() {
        // Safety net: save every 5 minutes in case events keep firing and the delayed save never triggers
        saveQueue.asyncAfter(deadline: .now() + 300) { [weak self] in
            guard let self = self else { return }
            if self.needsSave {
                self.save()
            }
            self.schedulePeriodicSave()
        }
    }
}
