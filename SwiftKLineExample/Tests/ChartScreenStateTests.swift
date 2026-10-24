//
//  ChartScreenStateTests.swift
//  SwiftKLineExampleTests
//
//  Created by zhwayne on 2026/10/24.
//

#if canImport(UIKit)
import Foundation
import Testing
import SwiftKLine

@MainActor private final class ScreenStore: ChartStateStore {
    private let memory = MemoryChartStateStore()
    private(set) var reads = 0
    private(set) var writes = 0
    func data(forKey key: String) -> Data? { reads += 1; return memory.data(forKey: key) }
    func set(_ data: Data, forKey key: String) { writes += 1; memory.set(data, forKey: key) }
    func removeValue(forKey key: String) { memory.removeValue(forKey: key) }
}

@available(iOS 17.0, *)
@Test @MainActor func screenStateRestoresOnceAndSavesOnlyPreferenceChanges() {
    let store = ScreenStore()
    let saved = ChartPreferences(period: ChartPeriod(seconds: 999, identifier: "1h"), indicators: IndicatorSelection())
    saved.save(to: store)
    let state = ChartScreenState(usesOfflineData: true, store: store)
    #expect(state.period == .oneHour)
    #expect(state.indicators == IndicatorSelection())
    let writes = store.writes, reads = store.reads
    state.mode = .timeSeries
    state.availableIndicators = [.ma]
    let unchanged = state.period
    state.period = unchanged
    #expect(store.writes == writes)
    #expect(store.reads == reads)
    state.period = .fiveMinutes
    #expect(store.writes == writes + 1)
    #expect(store.value(for: .chartPreferences)?.period == .fiveMinutes)
    state.indicators = IndicatorSelection(subIndicatorIDs: [.rsi])
    #expect(store.writes == writes + 2)
    #expect(store.value(for: .chartPreferences)?.indicators == state.indicators)
}

@available(iOS 17.0, *)
@Test @MainActor func screenAvailabilityDoesNotEraseTemporarilyUnavailablePreferences() {
    let store = ScreenStore()
    let requested = IndicatorSelection(mainIndicatorIDs: [.ma, .ema], subIndicatorIDs: [.vol])
    ChartPreferences(period: .oneMinute, indicators: requested).save(to: store)
    let state = ChartScreenState(usesOfflineData: true, store: store, availableIndicators: [.ma, .vol])
    #expect(state.indicators == requested)
    #expect(state.indicators.resolved(availableIndicators: state.availableIndicators).mainIndicatorIDs == [.ma])
    state.availableIndicators = BuiltInIndicator.allCases
    #expect(state.indicators.resolved(availableIndicators: state.availableIndicators) == requested)
    #expect(store.value(for: .chartPreferences)?.indicators == requested)
}

@available(iOS 17.0, *)
@Test @MainActor func screenRejectsUnsupportedStoredPeriodsBeforeSourceConstruction() {
    let store = ScreenStore()
    ChartPreferences(period: ChartPeriod(seconds: -1, identifier: "unsupported"),
                     indicators: IndicatorSelection()).save(to: store)
    let state = ChartScreenState(usesOfflineData: true, store: store)
    #expect(state.period == .oneMinute)
    #expect(store.value(for: .chartPreferences)?.period == .oneMinute)
}
@available(iOS 17.0, *)
@Test @MainActor func currentScreenPreferencesAreNotRewrittenOnLaunch() {
    let store = ScreenStore()
    let saved = ChartPreferences(period: .oneHour, indicators: IndicatorSelection(subIndicatorIDs: [.rsi]))
    saved.save(to: store)
    let writes = store.writes
    let state = ChartScreenState(usesOfflineData: true, store: store)
    #expect(state.period == .oneHour)
    #expect(state.indicators == saved.indicators)
    #expect(store.writes == writes)
    #expect(store.reads == 1)
}
#endif
