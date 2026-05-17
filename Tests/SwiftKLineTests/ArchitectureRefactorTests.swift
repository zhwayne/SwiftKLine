import Testing
import UIKit
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

@Test func indicatorIDSupportsStringLiteralAndRawValue() {
    let id: IndicatorID = "custom.vwap"

    #expect(id.rawValue == "custom.vwap")
    #expect(String(describing: id) == "custom.vwap")
}

@Test func builtInIndicatorMapsToStableOpenID() {
    #expect(BuiltInIndicator.ma.id == IndicatorID("builtin.ma"))
    #expect(BuiltInIndicator.macd.id == IndicatorID("builtin.macd"))
}

@Test func builtInIndicatorDefaultSeriesKeysAreStable() {
    let maKeys = BuiltInIndicator.ma.defaultSeriesKeys
    let macdKeys = BuiltInIndicator.macd.defaultSeriesKeys

    #expect(maKeys.first?.indicatorID == .ma)
    #expect(maKeys.first?.name == "MA")
    #expect(maKeys.first?.parameters == ["period": "5"])

    #expect(macdKeys.first?.indicatorID == .macd)
    #expect(macdKeys.first?.name == "MACD")
}

@Test @MainActor func chartConfigurationThemeBuildsAppearanceConfiguration() {
    let chart = ChartOptions(
        data: .deferred,
        appearance: .theme(.midnight),
        content: .candlestick,
        indicators: IndicatorSelectionState(main: [.ma], sub: [.vol]),
        features: [.liveUpdates, .gapRecovery, .indicatorPersistence],
        plugins: .default
    )

    #expect(chart.resolvedConfiguration.watermarkText == "SwiftKLine • Midnight")
    #expect(chart.content == .candlestick)
    #expect(chart.indicators?.main == [.ma])
    #expect(chart.features.contains(.liveUpdates))
}

private struct TestScalarCalculator: IndicatorCalculator {
    let id = SeriesKey(indicatorID: "test.scalar", name: "TEST")

    func calculate(for items: [any ChartItem]) -> [Double?] {
        items.map { Optional($0.close) }
    }
}

private struct TestIndicatorPlugin: IndicatorPlugin {
    let id: IndicatorID = "test.scalar"
    let title = "TEST"
    let placement: IndicatorPlacement = .sub
    let defaultSeriesKeys = [SeriesKey(indicatorID: "test.scalar", name: "TEST")]

    func makeCalculators(configuration: ChartConfiguration) -> [any IndicatorCalculator] {
        [TestScalarCalculator()]
    }

    @MainActor func makeRenderers(configuration: ChartConfiguration) -> [any ChartRenderer] {
        []
    }
}

private final class InMemoryIndicatorSelectionStore: IndicatorSelectionStore {
    var savedState: IndicatorSelectionState?

    func load() -> IndicatorSelectionState? {
        savedState
    }

    func save(state: IndicatorSelectionState) {
        savedState = state
    }

    func reset() {
        savedState = nil
    }
}

@MainActor private final class TestRenderer: ChartRenderer {
    let id = "test-renderer"

    func install(to layer: CALayer) {}
    func uninstall(from layer: CALayer) {}
    func draw(in layer: CALayer, context: Context) {}
}

@MainActor private final class RecordingRenderer: ChartRenderer {
    static var installCount = 0

    let id = "recording-renderer"

    func install(to layer: CALayer) {
        Self.installCount += 1
    }

    func uninstall(from layer: CALayer) {}
    func draw(in layer: CALayer, context: Context) {}
}

@Test @MainActor func pluginRegistryStoresPluginsPerInstance() {
    let first = PluginRegistry()
    let second = PluginRegistry()

    first.register(TestIndicatorPlugin())

    #expect(first.plugin(for: "test.scalar") != nil)
    #expect(second.plugin(for: "test.scalar") == nil)
}

@Test func indicatorSeriesStoreStoresAndReadsOpenKeySeries() {
    var store = IndicatorSeriesStore()
    let key = SeriesKey(indicatorID: "test.scalar", name: "TEST")

    store.setValues(ContiguousArray<Double?>([1, nil, 3]), for: key)

    let values = store.values(for: key, as: Double.self)
    #expect(values == ContiguousArray<Double?>([1, nil, 3]))
}

@Test func legacyMACalculatorWritesOpenSeriesKey() async {
    let items: [any ChartItem] = [
        TestChartItem(timestamp: 1, close: 1),
        TestChartItem(timestamp: 2, close: 2),
        TestChartItem(timestamp: 3, close: 3)
    ]

    let store = await [MACalculator(period: 2).eraseToAnyIndicatorCalculator()].calculate(items: items)
    let values = store.values(for: .ma(period: 2), as: Double.self)

    #expect(values?[0] == nil)
    #expect(values?[1] == 1.5)
    #expect(values?[2] == 2.5)
}

@Test @MainActor func defaultRegistryContainsBuiltInPlugins() {
    let registry = PluginRegistry.default

    #expect(registry.plugin(for: .ma) != nil)
    #expect(registry.plugin(for: .macd) != nil)
}

@Test @MainActor func builtInMAPluginCreatesCalculatorsAndRenderers() {
    let plugin = PluginRegistry.default.plugin(for: .ma)
    let configuration = ChartConfiguration()

    #expect(plugin?.defaultSeriesKeys == BuiltInIndicator.ma.defaultSeriesKeys)
    #expect(plugin?.makeCalculators(configuration: configuration).isEmpty == false)
    #expect(plugin?.makeRenderers(configuration: configuration).isEmpty == false)
}

@Test func chartStateDefaultsAreEmptyAndCandlestick() {
    let state = ChartState()

    #expect(state.items.isEmpty)
    #expect(state.contentStyle == .candlestick)
    #expect(state.selectedIndex == nil)
    #expect(state.lastError == nil)
}

@Test func dataMergerMergesHistoricalPageIntoState() {
    var merger = DataMerger()
    let items: [any ChartItem] = [
        TestChartItem(timestamp: 60, close: 1),
        TestChartItem(timestamp: 120, close: 2)
    ]

    merger.prepareBucketsIfNeeded(with: items)
    let result = merger.merge(current: [], patch: items)

    #expect(result.map(\.timestamp) == [60, 120])
}

@Test func dataMergerAppliesLiveTickReplacement() {
    var merger = DataMerger()
    let items: [any ChartItem] = [
        TestChartItem(timestamp: 60, close: 1),
        TestChartItem(timestamp: 120, close: 2)
    ]
    merger.prepareBucketsIfNeeded(with: items)
    var merged = merger.merge(current: [], patch: items)

    let result = merger.applyLiveTick(TestChartItem(timestamp: 120, close: 22), to: &merged)

    #expect(merged.map(\.close) == [1, 22])
    #expect(result == .replaced(index: 1))
}

@Test @MainActor func indicatorPipelineNormalizesAndPersistsSelection() {
    let normalizer = IndicatorSelectionNormalizer(availableMain: [.ma, .ema], availableSub: [.vol])
    let store = InMemoryIndicatorSelectionStore()
    let pipeline = IndicatorPipeline(
        configuration: ChartConfiguration(defaultMainIndicators: [.ma], defaultSubIndicators: [.vol]),
        normalizer: normalizer,
        selectionStore: store,
        registry: .default
    )

    let state = pipeline.setSelection(main: [.ma, .vol, .ema], sub: [.ema, .vol])

    #expect(state.mainIndicators == [.ma, .ema])
    #expect(state.subIndicators == [.vol])
    #expect(store.savedState == state)
}

@Test @MainActor func indicatorPipelinePersistsCustomSelection() {
    let normalizer = IndicatorSelectionNormalizer(availableMain: [.ma], availableSub: [.vol])
    let registry = PluginRegistry()
    registry.register(CloseEchoPlugin())
    let store = InMemoryIndicatorSelectionStore()
    let pipeline = IndicatorPipeline(
        configuration: ChartConfiguration(defaultMainIndicators: [.ma], defaultSubIndicators: [.vol]),
        normalizer: normalizer,
        selectionStore: store,
        registry: registry
    )

    let state = pipeline.setSelection(
        IndicatorSelectionState(main: [.ma, "custom.closeEcho"], sub: [.vol])
    )

    #expect(state.main == [.ma, "custom.closeEcho"])
    #expect(state.sub == [.vol])
    #expect(state.mainIndicators == [.ma])
    #expect(store.savedState == state)
}

@Test @MainActor func descriptorFactoryUsesInstanceRegistry() {
    let firstRegistry = PluginRegistry()
    let secondRegistry = PluginRegistry()
    firstRegistry.registerRenderer(placement: .overlay) { _, _ in [TestRenderer()] }

    let factory = DescriptorFactory()
    let config = ChartConfiguration()
    let first = factory.makeDescriptor(
        contentStyle: .candlestick,
        mainIndicators: [],
        subIndicators: [],
        customRenderers: [],
        configuration: config,
        layoutMetrics: config.layoutMetrics,
        registry: firstRegistry
    )
    let second = factory.makeDescriptor(
        contentStyle: .candlestick,
        mainIndicators: [],
        subIndicators: [],
        customRenderers: [],
        configuration: config,
        layoutMetrics: config.layoutMetrics,
        registry: secondRegistry
    )

    #expect(first.renderers.contains { String(describing: $0.id) == "test-renderer" })
    #expect(!second.renderers.contains { String(describing: $0.id) == "test-renderer" })
}

@Test @MainActor func chartCoordinatorUpdatesContentStyle() {
    let coordinator = ChartCoordinator(
        configuration: ChartConfiguration(),
        features: [],
        indicatorPipeline: IndicatorPipeline(
            configuration: ChartConfiguration(),
            normalizer: IndicatorSelectionNormalizer(availableMain: [], availableSub: []),
            selectionStore: nil,
            registry: .default
        )
    )

    coordinator.setContentStyle(.timeSeries)

    #expect(coordinator.state.contentStyle == .timeSeries)
}

private struct CloseEchoCalculator: IndicatorCalculator {
    let id = SeriesKey(indicatorID: "custom.closeEcho", name: "CloseEcho")

    func calculate(for items: [any ChartItem]) -> [Double?] {
        items.map { Optional($0.close) }
    }
}

private struct CloseEchoPlugin: IndicatorPlugin {
    let id: IndicatorID = "custom.closeEcho"
    let title = "Close Echo"
    let placement = IndicatorPlacement.main
    let defaultSeriesKeys = [SeriesKey(indicatorID: "custom.closeEcho", name: "CloseEcho")]

    func makeCalculators(configuration: ChartConfiguration) -> [any IndicatorCalculator] {
        [CloseEchoCalculator()]
    }

    @MainActor func makeRenderers(configuration: ChartConfiguration) -> [any ChartRenderer] {
        [RecordingRenderer()]
    }
}

private final class RecordingChartItemProvider: ChartItemProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var liveStreamRequests = 0
    private var recoveryRequests = 0

    var liveStreamRequestCount: Int {
        lock.withLock { liveStreamRequests }
    }

    var recoveryRequestCount: Int {
        lock.withLock { recoveryRequests }
    }

    func fetchChartItems(forPage page: Int) async throws -> [any ChartItem] {
        [
            TestChartItem(timestamp: 60, close: 1),
            TestChartItem(timestamp: 120, close: 2)
        ]
    }

    func fetchChartItems(from start: Date, to end: Date) async throws -> [any ChartItem] {
        lock.withLock { recoveryRequests += 1 }
        return []
    }

    func liveStream() -> AsyncStream<any ChartItem> {
        lock.withLock { liveStreamRequests += 1 }
        return AsyncStream { continuation in
            continuation.finish()
        }
    }
}

@Test @MainActor func externalCustomIndicatorCanBeRegisteredCalculatedAndRendered() async {
    let registry = PluginRegistry()
    registry.register(CloseEchoPlugin())
    let plugin = registry.plugin(for: "custom.closeEcho")
    let items: [any ChartItem] = [
        TestChartItem(timestamp: 1, close: 10),
        TestChartItem(timestamp: 2, close: 11)
    ]

    let calculators = plugin?.makeCalculators(configuration: ChartConfiguration()).map {
        $0.eraseToAnyIndicatorCalculator()
    } ?? []
    let store = await calculators.calculate(items: items)
    let values = store.values(for: SeriesKey(indicatorID: "custom.closeEcho", name: "CloseEcho"), as: Double.self)

    #expect(values == ContiguousArray<Double?>([10, 11]))
    #expect(plugin?.makeRenderers(configuration: ChartConfiguration()).isEmpty == false)
}

@Test @MainActor func chartConfigurationIndicatorsDriveInitialViewSelection() {
    let chart = ChartOptions(
        appearance: .configuration(
            ChartConfiguration(
                defaultMainIndicators: [.ma],
                defaultSubIndicators: [.vol]
            )
        ),
        indicators: IndicatorSelectionState(sub: [.macd]),
        features: []
    )

    let view = ChartView(options: chart)

    #expect(view.debugSelectedBuiltInIndicators.main == [])
    #expect(view.debugSelectedBuiltInIndicators.sub == [.macd])
}

@Test @MainActor func persistedIndicatorSelectionOverridesChartConfigurationWhenEnabled() {
    let store = InMemoryIndicatorSelectionStore()
    store.savedState = IndicatorSelectionState(mainIndicators: [.ema], subIndicators: [.rsi])
    let chart = ChartOptions(
        appearance: .configuration(
            ChartConfiguration(
                defaultMainIndicators: [.ma],
                defaultSubIndicators: [.vol]
            )
        ),
        indicators: IndicatorSelectionState(sub: [.macd]),
        features: [.indicatorPersistence]
    )

    let view = ChartView(options: chart, indicatorSelectionStore: store)

    #expect(view.debugSelectedBuiltInIndicators.main == [.ema])
    #expect(view.debugSelectedBuiltInIndicators.sub == [.rsi])
}

@Test @MainActor func chartConfigurationCanActivateCustomIndicator() {
    RecordingRenderer.installCount = 0
    let registry = PluginRegistry()
    registry.register(CloseEchoPlugin())
    let chart = ChartOptions(
        indicators: IndicatorSelectionState(main: ["custom.closeEcho"]),
        features: [],
        plugins: registry
    )

    _ = ChartView(options: chart)

    #expect(RecordingRenderer.installCount == 1)
}

@Test @MainActor func customIndicatorAppearsInIndicatorTypeViewAndCanBeToggled() {
    let registry = PluginRegistry()
    registry.register(CloseEchoPlugin())
    let chart = ChartOptions(
        indicators: IndicatorSelectionState(main: [], sub: []),
        features: [],
        plugins: registry
    )
    let view = ChartView(options: chart)

    #expect(view.debugIndicatorTypeTitles.main.contains("Close Echo"))

    view.debugToggleIndicator("custom.closeEcho", in: .mainChart)

    #expect(view.debugSelectedIndicators.main.contains("custom.closeEcho"))
}

@Test @MainActor func resetIndicatorsToDefaultUsesPipelineAndDropsCustomSelection() {
    let registry = PluginRegistry()
    registry.register(CloseEchoPlugin())
    let store = InMemoryIndicatorSelectionStore()
    let chart = ChartOptions(
        appearance: .configuration(
            ChartConfiguration(
                defaultMainIndicators: [.ma],
                defaultSubIndicators: [.vol]
            )
        ),
        indicators: IndicatorSelectionState(main: ["custom.closeEcho"], sub: []),
        features: [.indicatorPersistence],
        plugins: registry
    )
    let view = ChartView(options: chart, indicatorSelectionStore: store)

    view.resetIndicatorsToDefault()

    #expect(view.debugSelectedIndicators.main == [.ma])
    #expect(view.debugSelectedIndicators.sub == [.vol])
    #expect(store.savedState?.main == [.ma])
    #expect(store.savedState?.sub == [.vol])
}

@Test @MainActor func drawSynchronizesCoordinatorStateWithLegacyViewFields() async {
    let chart = ChartOptions(features: [])
    let view = ChartView(options: chart)
    let items: [any ChartItem] = [
        TestChartItem(timestamp: 60, close: 1),
        TestChartItem(timestamp: 120, close: 2)
    ]

    await view.debugDraw(items: items)

    #expect(view.debugItemTimestamps == [60, 120])
    #expect(view.debugCoordinatorItemTimestamps == [60, 120])
}

@Test func loaderDoesNotStartLiveStreamWhenLiveUpdatesAreDisabled() async throws {
    let provider = RecordingChartItemProvider()
    let loader = ChartItemLoader(
        provider: provider,
        enablesLiveUpdates: false,
        enablesGapRecovery: true,
        eventHandler: { _ in }
    )

    await loader.start()
    try await Task.sleep(nanoseconds: 50_000_000)
    await loader.stop()

    #expect(provider.liveStreamRequestCount == 0)
}

@Test func loaderDoesNotRecoverWhenGapRecoveryIsDisabled() async throws {
    let provider = RecordingChartItemProvider()
    let loader = ChartItemLoader(
        provider: provider,
        enablesLiveUpdates: true,
        enablesGapRecovery: false,
        eventHandler: { _ in }
    )

    await loader.start()
    await loader.didEnterBackground(latestTimestamp: 120)
    await loader.willEnterForeground(latestTimestamp: 120)
    try await Task.sleep(nanoseconds: 50_000_000)
    await loader.stop()

    #expect(provider.recoveryRequestCount == 0)
}
