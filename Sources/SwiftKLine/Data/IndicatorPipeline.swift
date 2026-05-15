import Foundation

@MainActor
struct IndicatorPipeline {
    private let configuration: KLineConfiguration
    private let normalizer: IndicatorSelectionNormalizer
    private let selectionStore: KLineIndicatorSelectionStore?
    private let calculationEngine: IndicatorCalculationEngine

    init(
        configuration: KLineConfiguration,
        normalizer: IndicatorSelectionNormalizer,
        selectionStore: KLineIndicatorSelectionStore?,
        registry: KLinePluginRegistry
    ) {
        self.configuration = configuration
        self.normalizer = normalizer.using(pluginRegistry: registry)
        self.selectionStore = selectionStore
        self.calculationEngine = IndicatorCalculationEngine(registry: registry)
    }

    func initialSelection() -> KLineIndicatorSelectionState {
        normalizer.normalize(selectionStore?.load())
    }

    func setSelection(main: [KLineIndicator], sub: [KLineIndicator]) -> KLineIndicatorSelectionState {
        setSelection(
            KLineIndicatorSelectionState(mainIndicators: main, subIndicators: sub)
        )
    }

    func setSelection(
        main: [KLineIndicatorSelection],
        sub: [KLineIndicatorSelection]
    ) -> KLineIndicatorSelectionState {
        setSelection(KLineIndicatorSelectionState(main: main, sub: sub))
    }

    func setSelection(_ state: KLineIndicatorSelectionState) -> KLineIndicatorSelectionState {
        let normalized = normalizer.normalize(
            state
        )
        selectionStore?.save(state: normalized)
        return normalized
    }

    func resetSelection() -> KLineIndicatorSelectionState {
        selectionStore?.reset()
        let state = KLineIndicatorSelectionState(
            mainIndicators: configuration.defaultMainIndicators,
            subIndicators: configuration.defaultSubIndicators
        )
        let normalized = normalizer.normalize(state)
        selectionStore?.save(state: normalized)
        return normalized
    }

    func calculate(
        items: [any KLineItem],
        mainIndicators: [KLineIndicator],
        subIndicators: [KLineIndicator]
    ) async -> IndicatorSeriesStore {
        return await calculationEngine.calculate(
            items: items,
            mainIndicators: mainIndicators,
            subIndicators: subIndicators,
            configuration: configuration
        )
    }

    func calculate(
        items: [any KLineItem],
        selection: KLineIndicatorSelectionState
    ) async -> IndicatorSeriesStore {
        return await calculationEngine.calculate(
            items: items,
            indicatorIDs: selection.indicatorIDs,
            configuration: configuration
        )
    }
}

extension KLineIndicatorSelectionState {
    var indicatorIDs: [KLineIndicatorID] {
        (main + sub).map(\.id)
    }
}
