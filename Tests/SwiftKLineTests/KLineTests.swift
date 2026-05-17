import Testing
@testable import SwiftKLine

private struct TestChartItem: ChartItem {
    let open: Double
    let close: Double
    let high: Double
    let low: Double
    let volume: Double
    let value: Double
    let timestamp: Int

    init(timestamp: Int, close: Double) {
        self.open = close
        self.close = close
        self.high = close
        self.low = close
        self.volume = 0
        self.value = 0
        self.timestamp = timestamp
    }
}

@Test func dataMergerSortsAndOverwritesByTimestamp() {
    var merger = DataMerger()
    let current: [any ChartItem] = [
        TestChartItem(timestamp: 120, close: 2),
        TestChartItem(timestamp: 60, close: 1),
    ]
    let patch: [any ChartItem] = [
        TestChartItem(timestamp: 120, close: 20),
        TestChartItem(timestamp: 180, close: 3),
    ]

    let merged = merger.merge(current: current, patch: patch)

    #expect(merged.map(\.timestamp) == [60, 120, 180])
    #expect(merged.map(\.close) == [1, 20, 3])
}

@Test func dataMergerReplacesLiveTickInExistingBucket() {
    var merger = DataMerger()
    var items: [any ChartItem] = [
        TestChartItem(timestamp: 60, close: 1),
        TestChartItem(timestamp: 120, close: 2),
        TestChartItem(timestamp: 180, close: 3),
    ]
    merger.prepareBucketsIfNeeded(with: items)

    let result = merger.applyLiveTick(TestChartItem(timestamp: 125, close: 22), to: &items)

    #expect(result == .replaced(index: 1))
    #expect(items.map(\.timestamp) == [60, 125, 180])
    #expect(items.map(\.close) == [1, 22, 3])
}

@Test func dataMergerInsertsLiveTickAtSortedBucketPosition() {
    var merger = DataMerger()
    var items: [any ChartItem] = [
        TestChartItem(timestamp: 60, close: 1),
        TestChartItem(timestamp: 180, close: 3),
    ]
    merger.prepareBucketsIfNeeded(with: [
        TestChartItem(timestamp: 60, close: 1),
        TestChartItem(timestamp: 120, close: 2),
    ])

    let result = merger.applyLiveTick(TestChartItem(timestamp: 120, close: 2), to: &items)

    #expect(result == .inserted(index: 1, appendedToTail: false))
    #expect(items.map(\.timestamp) == [60, 120, 180])
}

@Test func dataMergerReportsTailAppend() {
    var merger = DataMerger()
    var items: [any ChartItem] = [
        TestChartItem(timestamp: 60, close: 1),
        TestChartItem(timestamp: 120, close: 2),
    ]
    merger.prepareBucketsIfNeeded(with: items)

    let result = merger.applyLiveTick(TestChartItem(timestamp: 180, close: 3), to: &items)

    #expect(result == .inserted(index: 2, appendedToTail: true))
    #expect(items.map(\.timestamp) == [60, 120, 180])
}

@Test @MainActor func indicatorSelectionNormalizerFiltersInvalidAndDuplicateIndicators() {
    let normalizer = IndicatorSelectionNormalizer(
        availableMain: [.ma, .ema],
        availableSub: [.vol, .macd]
    )

    let normalized = normalizer.normalize(
        IndicatorSelectionState(
            mainIndicators: [.ma, .vol, .ma, .ema],
            subIndicators: [.macd, .ema, .vol, .macd]
        )
    )

    #expect(normalized.mainIndicators == [.ma, .ema])
    #expect(normalized.subIndicators == [.macd, .vol])
}

@Test func maCalculatorCalculatesMovingAverage() {
    let items: [any ChartItem] = [
        TestChartItem(timestamp: 1, close: 1),
        TestChartItem(timestamp: 2, close: 2),
        TestChartItem(timestamp: 3, close: 3),
        TestChartItem(timestamp: 4, close: 4),
    ]

    let values = MACalculator(period: 3).calculate(for: items)

    #expect(values.count == 4)
    #expect(values[0] == nil)
    #expect(values[1] == nil)
    #expect(values[2] == 2)
    #expect(values[3] == 3)
}

@Test func emaCalculatorCalculatesExpectedValues() {
    let items: [any ChartItem] = [
        TestChartItem(timestamp: 1, close: 1),
        TestChartItem(timestamp: 2, close: 2),
        TestChartItem(timestamp: 3, close: 3),
        TestChartItem(timestamp: 4, close: 4),
    ]

    let values = EMACalculator(period: 3).calculate(for: items)

    #expect(values.count == 4)
    #expect(values[0] == 1)
    #expect(values[1] == 1.5)
    #expect(values[2] == 2)
    #expect(values[3] == 3)
}

@MainActor
@Test func indicatorPipelineReturnsEmptyStoreWithoutCalculators() async {
    let pipeline = IndicatorPipeline(
        configuration: ChartConfiguration(),
        normalizer: IndicatorSelectionNormalizer(availableMain: [.ma], availableSub: []),
        selectionStore: nil,
        registry: .default
    )
    let store = await pipeline.calculate(
        items: [],
        mainIndicators: [],
        subIndicators: []
    )

    let maKey = SeriesKey.ma(period: 5)
    #expect(store.values(for: maKey, as: Double.self) == nil)
}

@MainActor
@Test func indicatorPipelineMergesCalculatorStores() async {
    let items: [any ChartItem] = [
        TestChartItem(timestamp: 1, close: 1),
        TestChartItem(timestamp: 2, close: 2),
        TestChartItem(timestamp: 3, close: 3),
        TestChartItem(timestamp: 4, close: 4),
    ]
    let configuration = ChartConfiguration(
        defaultMainIndicators: [.ma, .ema],
        defaultSubIndicators: [],
        indicatorKeyOverrides: [
            .ma: [.ma(period: 2)],
            .ema: [.ema(period: 3)]
        ]
    )

    let pipeline = IndicatorPipeline(
        configuration: configuration,
        normalizer: IndicatorSelectionNormalizer(availableMain: [.ma, .ema], availableSub: []),
        selectionStore: nil,
        registry: .default
    )
    let store = await pipeline.calculate(
        items: items,
        mainIndicators: [.ma, .ema],
        subIndicators: []
    )

    let maKey = SeriesKey.ma(period: 2)
    #expect(store.values(forKey: maKey, as: Double.self)?.count == 4)
    #expect(store.values(forKey: maKey, as: Double.self)?[1] == 1.5)
}
