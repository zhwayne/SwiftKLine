import Foundation

@MainActor
struct IndicatorPipeline {
    private let configuration: KLineConfiguration
    private let normalizer: IndicatorSelectionNormalizer
    private let selectionStore: IndicatorSelectionStore?
    private let registry: PluginRegistry

    init(
        configuration: KLineConfiguration,
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

    func setSelection(main: [KLineIndicator], sub: [KLineIndicator]) -> IndicatorSelectionState {
        setSelection(
            IndicatorSelectionState(mainIndicators: main, subIndicators: sub)
        )
    }

    func setSelection(
        main: [IndicatorSelection],
        sub: [IndicatorSelection]
    ) -> IndicatorSelectionState {
        setSelection(IndicatorSelectionState(main: main, sub: sub))
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

    // MARK: - Calculation (formerly IndicatorCalculationEngine)

    func calculate(
        items: [any KLineItem],
        mainIndicators: [KLineIndicator],
        subIndicators: [KLineIndicator]
    ) async -> IndicatorSeriesStore {
        await calculate(
            items: items,
            indicatorIDs: (mainIndicators + subIndicators).map(\.kLineID)
        )
    }

    func calculate(
        items: [any KLineItem],
        selection: IndicatorSelectionState
    ) async -> IndicatorSeriesStore {
        await calculate(
            items: items,
            indicatorIDs: selection.indicatorIDs
        )
    }

    private func calculate(
        items: [any KLineItem],
        indicatorIDs: [IndicatorID]
    ) async -> IndicatorSeriesStore {
        let calculators = indicatorIDs.flatMap { id -> [any KLineIndicatorCalculator] in
            if let indicator = KLineIndicator(kLineID: id) {
                return BuiltInIndicatorPlugin(indicator: indicator).makeCalculators(configuration: configuration)
            }
            return registry.plugin(for: id)?.makeCalculators(configuration: configuration) ?? []
        }
        let erased = calculators.map { $0.eraseToAnyIndicatorCalculator() }
        return await erased.calculate(items: items)
    }
}

extension IndicatorSelectionState {
    var indicatorIDs: [IndicatorID] {
        (main + sub).map(\.id)
    }
}
