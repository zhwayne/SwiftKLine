//
//  ChartPreferencesTests.swift
//  SwiftKLineExampleTests
//
//  Created by zhwayne on 2026/10/24.
//

#if canImport(UIKit)
import Foundation
import Testing
import SwiftKLine

@Test @MainActor func builtInStateStoresRoundTripTypedValues() throws {
    let periodKey = ChartStateKey<String>("test.period")
    let memory = MemoryChartStateStore()
    memory.set("5m", for: periodKey)
    #expect(memory.value(for: periodKey) == "5m")
    #expect(MemoryChartStateStore().value(for: periodKey) == nil)
    memory.removeValue(for: periodKey)
    #expect(memory.value(for: periodKey) == nil)

    let suiteName = "SwiftKLineTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsChartStateStore(defaults: defaults)
    store.set("1h", for: periodKey)
    #expect(store.value(for: periodKey) == "1h")
    store.removeValue(for: periodKey)
    #expect(store.value(for: periodKey) == nil)
    let unprefixed = UserDefaultsChartStateStore(defaults: defaults, namespace: "")
    unprefixed.set("4h", for: periodKey)
    #expect(defaults.data(forKey: periodKey.rawValue) != nil)
    #expect(unprefixed.value(for: periodKey) == "4h")
    unprefixed.removeValue(for: periodKey)
    #expect(defaults.data(forKey: periodKey.rawValue) == nil)
}


@Test @MainActor func preferenceRestorationIsReadOnlyAndSavingIsExplicit() throws {
    let store = RecordingPreferenceStore()
    let defaults = ChartPreferences(period: .oneMinute, indicators: IndicatorSelection(mainIndicatorIDs: [.ma]))
    #expect(ChartPreferences.restore(from: store, defaults: defaults) == defaults)
    #expect(store.writes == 0)
    let saved = ChartPreferences(period: .oneHour, indicators: IndicatorSelection())
    saved.save(to: store)
    #expect(store.writes == 1)
    #expect(ChartPreferences.restore(from: store, defaults: defaults) == saved)
    let chart = ChartView(configuration: try ChartConfiguration(source: CandleSource(id: "preferences", duration: 60) {
        SnapshotProvider(items: [])
    }, features: []), indicators: saved.indicators)
    defer { chart.shutdown() }
    chart.setIndicators(defaults.indicators)
    #expect(store.value(for: .chartPreferences) == saved)
    #expect(store.writes == 1)
}

@Test @MainActor func preferencesReadBothLegacyFormatsWithoutOverridingExplicitEmptyChoices() throws {
    let defaults = ChartPreferences(period: .fiveMinutes, indicators: IndicatorSelection(mainIndicatorIDs: [.ma]))
    let store = MemoryChartStateStore()
    let oldIndicators = IndicatorSelection(mainIndicatorIDs: [.ema], subIndicatorIDs: [.rsi])
    // Historical indicator-only records were property lists.
    store.set(try PropertyListEncoder().encode(oldIndicators), forKey: "indicator.selection")
    #expect(ChartPreferences.restore(from: store, defaults: defaults) ==
        ChartPreferences(period: .fiveMinutes, indicators: oldIndicators))
    let oldChart = ChartPreferences(period: .oneHour, indicators: IndicatorSelection())
    store.set(try JSONEncoder().encode(oldChart), forKey: "chart.selection")
    #expect(ChartPreferences.restore(from: store, defaults: defaults) == oldChart)
    let current = ChartPreferences(period: .oneMinute, indicators: IndicatorSelection())
    current.save(to: store)
    #expect(ChartPreferences.restore(from: store, defaults: defaults) == current)
    // A malformed current record falls through to a usable historical record.
    store.set(Data("invalid".utf8), forKey: "chart.preferences")
    #expect(ChartPreferences.restore(from: store, defaults: defaults) == oldChart)
    store.set(try PropertyListEncoder().encode(oldChart), forKey: "chart.selection")
    #expect(ChartPreferences.restore(from: store, defaults: defaults) == oldChart)
    store.set(Data("invalid".utf8), forKey: "chart.selection")
    store.set(Data("invalid".utf8), forKey: "indicator.selection")
    #expect(ChartPreferences.restore(from: store, defaults: defaults) == defaults)
}

@Test @MainActor func preferenceNamespacesRemainIndependent() throws {
    let suiteName = "SwiftKLineTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let first = UserDefaultsChartStateStore(defaults: defaults, namespace: "chart.first")
    let second = UserDefaultsChartStateStore(defaults: defaults, namespace: "chart.second")
    let initial = ChartPreferences(period: .oneMinute, indicators: IndicatorSelection())
    let saved = ChartPreferences(period: .oneHour, indicators: IndicatorSelection(subIndicatorIDs: [.rsi]))
    saved.save(to: first)
    #expect(ChartPreferences.restore(from: first, defaults: initial) == saved)
    #expect(ChartPreferences.restore(from: second, defaults: initial) == initial)
    initial.save(to: second)
    #expect(ChartPreferences.restore(from: first, defaults: initial) == saved)
}

@MainActor
private final class RecordingPreferenceStore: ChartStateStore {
    private let memory = MemoryChartStateStore()
    private(set) var writes = 0
    func data(forKey key: String) -> Data? { memory.data(forKey: key) }
    func set(_ data: Data, forKey key: String) { writes += 1; memory.set(data, forKey: key) }
    func removeValue(forKey key: String) { memory.removeValue(forKey: key) }
}

#endif
