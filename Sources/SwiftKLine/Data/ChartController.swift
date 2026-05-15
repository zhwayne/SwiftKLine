import Foundation

@MainActor
struct ChartController {
    var state: ChartState
    private var dataPipeline: DataPipeline
    private var indicatorPipeline: IndicatorPipeline?

    init(
        state: ChartState = ChartState(),
        dataPipeline: DataPipeline = DataPipeline(),
        indicatorPipeline: IndicatorPipeline? = nil
    ) {
        self.state = state
        self.dataPipeline = dataPipeline
        self.indicatorPipeline = indicatorPipeline
    }

    mutating func reset() {
        state = ChartState(
            contentStyle: state.contentStyle,
            indicatorSelection: state.indicatorSelection
        )
        dataPipeline.reset()
    }

    mutating func setChartContentStyle(_ style: KLineChartContentStyle) {
        state.contentStyle = style
    }

    mutating func setIndicators(main: [KLineIndicator], sub: [KLineIndicator]) {
        setIndicatorSelection(
            KLineIndicatorSelectionState(mainIndicators: main, subIndicators: sub)
        )
    }

    mutating func setIndicatorSelection(_ selection: KLineIndicatorSelectionState) {
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
    mutating func applyLoaderEvent(_ event: KLineItemLoaderEvent) -> LiveTickMergeResult? {
        dataPipeline.apply(event, to: &state)
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
        return await IndicatorCalculationEngine().calculate(
            items: items,
            mainIndicators: mainIndicators,
            subIndicators: subIndicators,
            configuration: configuration
        )
    }

    func calculateIndicators(
        items: [any KLineItem],
        selection: KLineIndicatorSelectionState,
        configuration: KLineConfiguration
    ) async -> IndicatorSeriesStore {
        if let indicatorPipeline {
            return await indicatorPipeline.calculate(items: items, selection: selection)
        }
        return await IndicatorCalculationEngine().calculate(
            items: items,
            indicatorIDs: selection.indicatorIDs,
            configuration: configuration
        )
    }
}
