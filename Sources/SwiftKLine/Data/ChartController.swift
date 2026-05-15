import Foundation

@MainActor
struct ChartController {
    var state: ChartState
    private var dataMerger = DataMerger()
    private var indicatorPipeline: IndicatorPipeline?

    init(
        state: ChartState = ChartState(),
        indicatorPipeline: IndicatorPipeline? = nil
    ) {
        self.state = state
        self.indicatorPipeline = indicatorPipeline
    }

    mutating func reset() {
        state = ChartState(
            contentStyle: state.contentStyle,
            indicatorSelection: state.indicatorSelection
        )
        dataMerger.reset()
    }

    mutating func setChartContentStyle(_ style: ChartType) {
        state.contentStyle = style
    }

    mutating func setIndicators(main: [KLineIndicator], sub: [KLineIndicator]) {
        setIndicatorSelection(
            IndicatorSelectionState(mainIndicators: main, subIndicators: sub)
        )
    }

    mutating func setIndicatorSelection(_ selection: IndicatorSelectionState) {
        if let normalized = indicatorPipeline?.setSelection(selection) {
            state.indicatorSelection = normalized
        } else {
            state.indicatorSelection = selection
        }
    }

    mutating func resetIndicatorSelection() {
        if let selection = indicatorPipeline?.resetSelection() {
            state.indicatorSelection = selection
        }
    }

    @discardableResult
    mutating func applyLoaderEvent(_ event: DataLoaderEvent) -> LiveTickMergeResult? {
        switch event {
        case let .page(index, items):
            if index == 0 {
                dataMerger.prepareBucketsIfNeeded(with: items)
                state.items = items
            } else {
                state.items = dataMerger.merge(current: state.items, patch: items)
            }
        case let .recovery(items):
            state.items = dataMerger.merge(current: state.items, patch: items)
        case let .liveTick(tick):
            return dataMerger.applyLiveTick(tick, to: &state.items)
        case let .failed(error):
            state.lastError = error
        }
        return nil
    }

    mutating func recalculateIndicators(configuration: KLineConfiguration) async {
        guard let indicatorPipeline else { return }
        state.indicatorSeriesStore = await indicatorPipeline.calculate(
            items: state.items,
            selection: state.indicatorSelection
        )
    }

    func calculateIndicators(
        items: [any KLineItem],
        mainIndicators: [KLineIndicator],
        subIndicators: [KLineIndicator],
        configuration: KLineConfiguration
    ) async -> IndicatorSeriesStore {
        if let indicatorPipeline {
            return await indicatorPipeline.calculate(
                items: items,
                mainIndicators: mainIndicators,
                subIndicators: subIndicators
            )
        }
        // Fallback: create a temporary pipeline for calculation
        let tempPipeline = IndicatorPipeline(
            configuration: configuration,
            normalizer: IndicatorSelectionNormalizer(
                availableMain: configuration.indicators.filter(\.isMain),
                availableSub: configuration.indicators.filter { !$0.isMain }
            ),
            selectionStore: nil,
            registry: .default
        )
        return await tempPipeline.calculate(
            items: items,
            mainIndicators: mainIndicators,
            subIndicators: subIndicators
        )
    }

    func calculateIndicators(
        items: [any KLineItem],
        selection: IndicatorSelectionState,
        configuration: KLineConfiguration
    ) async -> IndicatorSeriesStore {
        if let indicatorPipeline {
            return await indicatorPipeline.calculate(items: items, selection: selection)
        }
        let tempPipeline = IndicatorPipeline(
            configuration: configuration,
            normalizer: IndicatorSelectionNormalizer(
                availableMain: configuration.indicators.filter(\.isMain),
                availableSub: configuration.indicators.filter { !$0.isMain }
            ),
            selectionStore: nil,
            registry: .default
        )
        return await tempPipeline.calculate(items: items, selection: selection)
    }
}
