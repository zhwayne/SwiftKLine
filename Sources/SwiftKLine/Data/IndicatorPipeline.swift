import Foundation

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

    func initialSelection() -> IndicatorSelectionState {
        normalizer.normalize(selectionStore?.load())
    }

    func setSelection(main: [BuiltInIndicator], sub: [BuiltInIndicator]) -> IndicatorSelectionState {
        setSelection(
            IndicatorSelectionState(mainIndicators: main, subIndicators: sub)
        )
    }

    func setSelection(_ state: IndicatorSelectionState) -> IndicatorSelectionState {
        let normalized = normalizer.normalize(state)
        selectionStore?.save(state: normalized)
        return normalized
    }

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

    func calculate(
        items: [any ChartItem],
        selection: IndicatorSelectionState
    ) async -> IndicatorSeriesStore {
        await calculate(
            items: items,
            indicatorIDs: selection.indicatorIDs
        )
    }

    private func calculate(
        items: [any ChartItem],
        indicatorIDs: [IndicatorID]
    ) async -> IndicatorSeriesStore {
        let calculators = indicatorIDs.flatMap { id -> [any IndicatorCalculator] in
            if let indicator = BuiltInIndicator(id: id) {
                return BuiltInIndicatorPlugin(indicator: indicator).makeCalculators(configuration: configuration)
            }
            return registry.plugin(for: id)?.makeCalculators(configuration: configuration) ?? []
        }
        let erased = calculators.map { $0.eraseToAnyIndicatorCalculator() }
        return await erased.calculate(items: items)
    }
}