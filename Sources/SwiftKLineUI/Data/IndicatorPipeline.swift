//
//  IndicatorPipeline.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/05/17.
//

import SwiftKLineCore
import Foundation

/// Bridges main-actor selection and plugin configuration to Sendable calculation work.
///
/// Selection normalization and persistence stay on the main actor. The engine receives only immutable candle,
/// calculator, and output snapshots; this pipeline owns no implicit calculation cache.
@MainActor
struct IndicatorPipeline {
    private let configuration: ChartConfiguration
    private let normalizer: IndicatorSelectionNormalizer
    private let selectionStore: IndicatorSelectionStore?
    private let registry: PluginRegistry

    init(
        configuration: ChartConfiguration,
        normalizer: IndicatorSelectionNormalizer,
        selectionStore: IndicatorSelectionStore?,
        registry: PluginRegistry
    ) {
        self.configuration = configuration
        self.normalizer = normalizer.using(pluginRegistry: registry)
        self.selectionStore = selectionStore
        self.registry = registry
    }

    /// Loads and normalizes saved selection; ChartView applies declared or configuration fallback selection separately.
    func initialSelection() -> IndicatorSelectionState {
        normalizer.normalize(selectionStore?.load())
    }

    /// Normalizes the submitted selection, persists the result, and returns the accepted IDs.
    func setSelection(main: [BuiltInIndicator], sub: [BuiltInIndicator]) -> IndicatorSelectionState {
        setSelection(
            IndicatorSelectionState(mainIndicators: main, subIndicators: sub)
        )
    }

    /// Normalizes the submitted selection, persists the result, and returns the accepted IDs.
    func setSelection(_ state: IndicatorSelectionState) -> IndicatorSelectionState {
        let normalized = normalizer.normalize(state)
        selectionStore?.save(state: normalized)
        return normalized
    }

    /// Clears saved selection, normalizes configured defaults, and saves the restored state.
    func resetSelection() -> IndicatorSelectionState {
        selectionStore?.reset()
        let state = IndicatorSelectionState(
            mainIndicators: configuration.defaultMainIndicators,
            subIndicators: configuration.defaultSubIndicators
        )
        let normalized = normalizer.normalize(state)
        selectionStore?.save(state: normalized)
        return normalized
    }

    // MARK: - Calculation

    /// Resolves calculators from the same registry used for rendering and delegates snapshot computation to IndicatorEngine.
    func calculate(
        items: [any ChartItem],
        mainIndicators: [BuiltInIndicator],
        subIndicators: [BuiltInIndicator]
    ) async -> IndicatorSeriesStore {
        await calculate(
            items: items,
            indicatorIDs: (mainIndicators + subIndicators).map(\.id)
        )
    }

    /// Resolves calculators from the same registry used for rendering and delegates snapshot computation to IndicatorEngine.
    func calculate(
        items: [any ChartItem],
        selection: IndicatorSelectionState,
        previous: IndicatorSeriesStore? = nil,
        invalidatedFrom: Int = 0
    ) async -> IndicatorSeriesStore {
        await calculate(
            items: items,
            indicatorIDs: selection.indicatorIDs,
            previous: previous,
            invalidatedFrom: invalidatedFrom
        )
    }

    private func calculate(
        items: [any ChartItem],
        indicatorIDs: [IndicatorID],
        previous: IndicatorSeriesStore? = nil,
        invalidatedFrom: Int = 0
    ) async -> IndicatorSeriesStore {
        let calculators = indicatorIDs.flatMap { id -> [any IndicatorCalculator] in
            // Resolve calculations from the same registry as rendering, including replacements of built-in IDs.
            return registry.plugin(for: id)?.makeCalculators(configuration: configuration) ?? []
        }
        let erased = calculators.map { $0.eraseToAnyIndicatorCalculator() }
        return await IndicatorEngine.calculate(items: items, calculators: erased, previous: previous, invalidatedFrom: invalidatedFrom)
    }
}