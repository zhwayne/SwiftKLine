//
//  ChartPreferences.swift
//  SwiftKLineExample
//
//  Created by zhwayne on 2026/10/23.
//

#if canImport(UIKit)
import SwiftKLine

/// An optional storage snapshot owned by the application, independent of the chart runtime.
/// Restore and validate it before constructing a source; save it when application controls change.
struct ChartPreferences: Codable, Equatable, Sendable {
    /// The application's preferred provider period.
    var period: ChartPeriod
    /// The application's ordered built-in indicator choices.
    var indicators: IndicatorSelection

    init(period: ChartPeriod, indicators: IndicatorSelection) {
        self.period = period
        self.indicators = indicators
    }

    /// Reads current preferences, then legacy chart/indicator records, then the supplied defaults.
    /// Does not write or validate values; the application decides its available periods and indicators.
    @MainActor
    static func restore(from store: any ChartStateStore, defaults: ChartPreferences) -> ChartPreferences {
        if let saved = store.value(for: ChartStateKey<ChartPreferences>.chartPreferences) { return saved }
        if let legacy = store.value(for: ChartStateKey<ChartPreferences>("chart.selection")) { return legacy }
        var result = defaults
        if let legacy = store.value(for: ChartStateKey<IndicatorSelection>("indicator.selection")) {
            result.indicators = legacy
        }
        return result
    }

    /// Explicitly saves a snapshot after application-owned validation or control changes.
    @MainActor
    func save(to store: any ChartStateStore) {
        store.set(self, for: .chartPreferences)
    }
}
#endif
