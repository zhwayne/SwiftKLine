import Testing
@testable import SwiftKLine

private struct TestKLineItem: KLineItem {
    let opening: Double
    let closing: Double
    let highest: Double
    let lowest: Double
    let volume: Double
    let value: Double
    let timestamp: Int

    init(timestamp: Int, closing: Double) {
        self.opening = closing
        self.closing = closing
        self.highest = closing
        self.lowest = closing
        self.volume = 0
        self.value = 0
        self.timestamp = timestamp
    }
}

@Test func dataMergerSortsAndOverwritesByTimestamp() {
    var merger = DataMerger()
    let current: [any KLineItem] = [
        TestKLineItem(timestamp: 120, closing: 2),
        TestKLineItem(timestamp: 60, closing: 1),
    ]
    let patch: [any KLineItem] = [
        TestKLineItem(timestamp: 120, closing: 20),
        TestKLineItem(timestamp: 180, closing: 3),
    ]

    let merged = merger.merge(current: current, patch: patch)

    #expect(merged.map(\.timestamp) == [60, 120, 180])
    #expect(merged.map(\.closing) == [1, 20, 3])
}

@Test func dataMergerReplacesLiveTickInExistingBucket() {
    var merger = DataMerger()
    var items: [any KLineItem] = [
        TestKLineItem(timestamp: 60, closing: 1),
        TestKLineItem(timestamp: 120, closing: 2),
        TestKLineItem(timestamp: 180, closing: 3),
    ]
    merger.prepareBucketsIfNeeded(with: items)

    let result = merger.applyLiveTick(TestKLineItem(timestamp: 125, closing: 22), to: &items)

    #expect(result == .replaced(index: 1))
    #expect(items.map(\.timestamp) == [60, 125, 180])
    #expect(items.map(\.closing) == [1, 22, 3])
}

@Test func dataMergerInsertsLiveTickAtSortedBucketPosition() {
    var merger = DataMerger()
    var items: [any KLineItem] = [
        TestKLineItem(timestamp: 60, closing: 1),
        TestKLineItem(timestamp: 180, closing: 3),
    ]
    merger.prepareBucketsIfNeeded(with: [
        TestKLineItem(timestamp: 60, closing: 1),
        TestKLineItem(timestamp: 120, closing: 2),
    ])

    let result = merger.applyLiveTick(TestKLineItem(timestamp: 120, closing: 2), to: &items)

    #expect(result == .inserted(index: 1, appendedToTail: false))
    #expect(items.map(\.timestamp) == [60, 120, 180])
}

@Test func dataMergerReportsTailAppend() {
    var merger = DataMerger()
    var items: [any KLineItem] = [
        TestKLineItem(timestamp: 60, closing: 1),
        TestKLineItem(timestamp: 120, closing: 2),
    ]
    merger.prepareBucketsIfNeeded(with: items)

    let result = merger.applyLiveTick(TestKLineItem(timestamp: 180, closing: 3), to: &items)

    #expect(result == .inserted(index: 2, appendedToTail: true))
    #expect(items.map(\.timestamp) == [60, 120, 180])
}

@Test @MainActor func indicatorSelectionNormalizerFiltersInvalidAndDuplicateIndicators() {
    let normalizer = IndicatorSelectionNormalizer(
        availableMain: [.ma, .ema],
        availableSub: [.vol, .macd]
    )

    let normalized = normalizer.normalize(
        KLineIndicatorSelectionState(
            mainIndicators: [.ma, .vol, .ma, .ema],
            subIndicators: [.macd, .ema, .vol, .macd]
        )
    )

    #expect(normalized.mainIndicators == [.ma, .ema])
    #expect(normalized.subIndicators == [.macd, .vol])
}

@Test func maCalculatorCalculatesMovingAverage() {
    let items: [any KLineItem] = [
        TestKLineItem(timestamp: 1, closing: 1),
        TestKLineItem(timestamp: 2, closing: 2),
        TestKLineItem(timestamp: 3, closing: 3),
        TestKLineItem(timestamp: 4, closing: 4),
    ]

    let values = MACalculator(period: 3).calculate(for: items)

    #expect(values.count == 4)
    #expect(values[0] == nil)
    #expect(values[1] == nil)
    #expect(values[2] == 2)
    #expect(values[3] == 3)
}

@Test func emaCalculatorCalculatesExpectedValues() {
    let items: [any KLineItem] = [
        TestKLineItem(timestamp: 1, closing: 1),
        TestKLineItem(timestamp: 2, closing: 2),
        TestKLineItem(timestamp: 3, closing: 3),
        TestKLineItem(timestamp: 4, closing: 4),
    ]

    let values = EMACalculator(period: 3).calculate(for: items)

    #expect(values.count == 4)
    #expect(values[0] == 1)
    #expect(values[1] == 1.5)
    #expect(values[2] == 2)
    #expect(values[3] == 3)
}

@MainActor
@Test func indicatorCalculationEngineReturnsEmptyStoreWithoutCalculators() async {
    let engine = IndicatorCalculationEngine()
    let store = await engine.calculate(
        items: [],
        mainIndicators: [],
        subIndicators: [],
        configuration: KLineConfiguration()
    )

    let maKey = KLineIndicator.Key.ma(5).kLineSeriesKey
    #expect(store.values(for: maKey, as: Double.self) == nil)
}

@MainActor
@Test func indicatorCalculationEngineMergesCalculatorStores() async {
    let items: [any KLineItem] = [
        TestKLineItem(timestamp: 1, closing: 1),
        TestKLineItem(timestamp: 2, closing: 2),
        TestKLineItem(timestamp: 3, closing: 3),
        TestKLineItem(timestamp: 4, closing: 4),
    ]
    let configuration = KLineConfiguration(
        defaultMainIndicators: [.ma, .ema],
        defaultSubIndicators: [],
        indicatorKeyOverrides: [
            .ma: [.ma(2)],
            .ema: [.ema(3)]
        ]
    )

    let store = await IndicatorCalculationEngine().calculate(
        items: items,
        mainIndicators: [.ma, .ema],
        subIndicators: [],
        configuration: configuration
    )

    let maKey = KLineIndicator.Key.ma(2).kLineSeriesKey
    #expect(store.values(for: maKey, as: Double.self)?.count == 4)
    #expect(store.values(for: maKey, as: Double.self)?[1] == 1.5)
}
