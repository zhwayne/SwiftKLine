//
//  ChartSelectionController.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/10/21.
//

import SwiftKLineCore

/// Owns restoration, normalization, configuration construction and selection persistence.
@MainActor
final class ChartSelectionController {
    private let stateStore: (any ChartStateStore)?
    private let initialSelection: ChartSelection
    private var availablePeriods: [ChartPeriod]
    private var makeConfiguration: (ChartSelection) -> ChartConfiguration
    private(set) var selection: ChartSelection
    private(set) var configuration: ChartConfiguration

    init(selection initial: ChartSelection, availablePeriods: [ChartPeriod],
         stateStore: (any ChartStateStore)?, configuration: @escaping (ChartSelection) -> ChartConfiguration) {
        self.stateStore = stateStore
        initialSelection = initial
        self.availablePeriods = availablePeriods
        makeConfiguration = configuration
        let saved = stateStore?.value(for: ChartStateKey<ChartSelection>.chartSelection)
        var restored = saved ?? initial
        // Older releases stored indicators independently. Preserve that payload without exposing its key.
        if saved == nil,
           let legacy = stateStore?.value(for: ChartStateKey<IndicatorSelection>("indicator.selection")) {
            restored.indicators = legacy
        }
        restored.period = Self.normalizedPeriod(restored.period, available: availablePeriods, fallback: initial.period)
        let declared = configuration(restored)
        let normalized = Self.normalizedIndicators(restored.indicators, appearance: declared.appearance)
        let indicatorsChanged = normalized != restored.indicators
        restored.indicators = normalized
        selection = restored
        self.configuration = indicatorsChanged ? configuration(restored) : declared
        persist()
    }

    func apply(_ requested: ChartSelection?, availablePeriods: [ChartPeriod],
               configuration: @escaping (ChartSelection) -> ChartConfiguration) {
        self.availablePeriods = availablePeriods
        makeConfiguration = configuration
        var resolved = requested ?? selection
        resolved.period = Self.normalizedPeriod(resolved.period, available: availablePeriods, fallback: initialSelection.period)
        let declared = configuration(resolved)
        let normalized = Self.normalizedIndicators(resolved.indicators, appearance: declared.appearance)
        let indicatorsChanged = normalized != resolved.indicators
        resolved.indicators = normalized
        let changed = resolved != selection
        selection = resolved
        self.configuration = indicatorsChanged ? configuration(resolved) : declared
        if changed { persist() }
    }

    func set(_ selection: ChartSelection) {
        apply(selection, availablePeriods: availablePeriods, configuration: makeConfiguration)
    }

    func reset() {
        set(ChartSelection(period: initialSelection.period, indicators: Self.defaults(for: configuration.appearance)))
    }

    func configuredChart() -> ChartConfiguration {
        let indicators = selection.indicators
        let chosen = (indicators.mainIndicators + indicators.subIndicators).map {
            BuiltInIndicatorPlugin(indicator: $0, appearance: configuration.appearance) as any ChartPlugin
        }
        return configuration.includingSelectedIndicators(chosen)
    }

    static func defaults(for appearance: ChartAppearance) -> IndicatorSelection {
        IndicatorSelection(mainIndicators: appearance.defaultMainIndicators, subIndicators: appearance.defaultSubIndicators)
    }

    private static func normalizedPeriod(_ period: ChartPeriod, available: [ChartPeriod], fallback: ChartPeriod) -> ChartPeriod {
        func valid(_ period: ChartPeriod) -> Bool { period.seconds > 0 && !period.identifier.isEmpty }
        let available = available.filter(valid)
        if let canonical = available.first(where: { $0.identifier == period.identifier }) { return canonical }
        if let first = available.first { return first }
        if valid(period) { return period }
        return valid(fallback) ? fallback : .oneMinute
    }

    private static func normalizedIndicators(_ selection: IndicatorSelection, appearance: ChartAppearance) -> IndicatorSelection {
        let available = Set(appearance.indicators)
        func filter(_ ids: [IndicatorID], main: Bool) -> [IndicatorID] {
            var seen = Set<IndicatorID>()
            return ids.filter { id in
                guard let indicator = BuiltInIndicator(id: id), available.contains(indicator), indicator.isMain == main else { return false }
                return seen.insert(id).inserted
            }
        }
        return IndicatorSelection(mainIndicatorIDs: filter(selection.mainIndicatorIDs, main: true),
                                  subIndicatorIDs: filter(selection.subIndicatorIDs, main: false))
    }

    private func persist() { stateStore?.set(selection, for: .chartSelection) }
}
