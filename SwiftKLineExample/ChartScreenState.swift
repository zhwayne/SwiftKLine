//
//  ChartScreenState.swift
//  SwiftKLineExample
//
//  Created by zhwayne on 2026/10/24.
//

#if canImport(UIKit)
import Observation
import SwiftKLine

/// Display choices exposed by the example’s main-chart segmented control.
enum ChartDisplayMode: String, CaseIterable, Identifiable {
    case candlestick
    case timeSeries

    var id: Self { self }

    var title: String {
        switch self {
        case .candlestick: return "K线"
        case .timeSeries: return "分时"
        }
    }
}

/// Application-owned state with one restoration and an explicit preference lifecycle.
@available(iOS 17.0, *)
@Observable @MainActor
final class ChartScreenState {
    var period: ChartPeriod { didSet { persistChanges() } }
    var indicators: IndicatorSelection { didSet { persistChanges() } }
    var mode: ChartDisplayMode = .candlestick
    var availableIndicators: [BuiltInIndicator]
    let usesOfflineData: Bool
    @ObservationIgnored private let store: any ChartStateStore
    @ObservationIgnored private var lastSaved: ChartPreferences?

    init(usesOfflineData: Bool = false, store: (any ChartStateStore)? = nil,
         availableIndicators: [BuiltInIndicator] = BuiltInIndicator.allCases) {
        self.usesOfflineData = usesOfflineData
        self.availableIndicators = availableIndicators
        let effectiveStore: any ChartStateStore = store
            ?? (usesOfflineData ? MemoryChartStateStore() : UserDefaultsChartStateStore())
        self.store = effectiveStore
        let defaults = ChartPreferences(period: .oneMinute,
            indicators: IndicatorSelection(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol, .macd]))
        let current = effectiveStore.value(for: ChartStateKey<ChartPreferences>.chartPreferences)
        let restored = current ?? ChartPreferences.restore(from: effectiveStore, defaults: defaults)
        period = DemoChartPeriod.all.first { $0.period.identifier == restored.period.identifier }?.period ?? defaults.period
        indicators = restored.indicators
        lastSaved = current
        // Commit defaults, canonicalization or migration; do not rewrite a current unchanged snapshot.
        persistChanges()
    }

    private func persistChanges() {
        let snapshot = ChartPreferences(period: period, indicators: indicators)
        guard snapshot != lastSaved else { return }
        snapshot.save(to: store)
        lastSaved = snapshot
    }
}
#endif
