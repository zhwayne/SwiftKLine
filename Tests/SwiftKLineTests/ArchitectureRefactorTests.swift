import Testing
import UIKit
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

@Test func indicatorIDSupportsStringLiteralAndRawValue() {
    let id: KLineIndicatorID = "custom.vwap"

    #expect(id.rawValue == "custom.vwap")
    #expect(String(describing: id) == "custom.vwap")
}

@Test func builtInIndicatorMapsToStableOpenID() {
    #expect(KLineIndicator.ma.kLineID == KLineIndicatorID("builtin.ma"))
    #expect(KLineIndicator.macd.kLineID == KLineIndicatorID("builtin.macd"))
}

@Test func builtInIndicatorKeysMapToStableSeriesKeys() {
    let ma = KLineIndicator.Key.ma(5).kLineSeriesKey
    let macd = KLineIndicator.Key.macd(shortPeriod: 12, longPeriod: 26, signalPeriod: 9).kLineSeriesKey

    #expect(ma.indicatorID == "builtin.ma")
    #expect(ma.name == "MA")
    #expect(ma.parameters == ["period": "5"])
    #expect(String(describing: ma) == "builtin.ma.MA(period=5)")

    #expect(macd.indicatorID == "builtin.macd")
    #expect(macd.name == "MACD")
    #expect(macd.parameters == ["longPeriod": "26", "shortPeriod": "12", "signalPeriod": "9"])
}

@Test @MainActor func chartConfigurationThemeBuildsAppearanceConfiguration() {
    let chart = KLineChartConfiguration(
        data: .deferred,
        appearance: .theme(.midnight),
        content: .candlestick,
        indicators: .init(main: [.builtIn(.ma)], sub: [.builtIn(.vol)]),
        features: [.liveUpdates, .gapRecovery, .indicatorPersistence],
        plugins: .default
    )

    #expect(chart.resolvedConfiguration.watermarkText == "SwiftKLine • Midnight")
    #expect(chart.content == .candlestick)
    #expect(chart.indicators.main == [.builtIn(.ma)])
    #expect(chart.features.contains(.liveUpdates))
}

private struct TestScalarCalculator: KLineIndicatorCalculator {
    let id = KLineSeriesKey(indicatorID: "test.scalar", name: "TEST")

    func calculate(for items: [any KLineItem]) -> [Double?] {
        items.map { Optional($0.closing) }
    }
}

private struct TestIndicatorPlugin: KLineIndicatorPlugin {
    let id: KLineIndicatorID = "test.scalar"
    let title = "TEST"
    let placement: KLineIndicatorPlacement = .sub
    let defaultSeriesKeys = [KLineSeriesKey(indicatorID: "test.scalar", name: "TEST")]

    func makeCalculators(configuration: KLineConfiguration) -> [any KLineIndicatorCalculator] {
        [TestScalarCalculator()]
    }

    @MainActor func makeRenderers(configuration: KLineConfiguration) -> [any KLineRenderer] {
        []
    }
}

private final class InMemoryIndicatorSelectionStore: KLineIndicatorSelectionStore {
    var savedState: KLineIndicatorSelectionState?

    func load() -> KLineIndicatorSelectionState? {
        savedState
    }

    func save(state: KLineIndicatorSelectionState) {
        savedState = state
    }

    func reset() {
        savedState = nil
    }
}

@MainActor private final class TestRenderer: KLineRenderer {
    let id = "test-renderer"

    func install(to layer: CALayer) {}
    func uninstall(from layer: CALayer) {}
    func draw(in layer: CALayer, context: Context) {}
}

@MainActor private final class RecordingRenderer: KLineRenderer {
    static var installCount = 0

    let id = "recording-renderer"

    func install(to layer: CALayer) {
        Self.installCount += 1
    }

    func uninstall(from layer: CALayer) {}
    func draw(in layer: CALayer, context: Context) {}
}

@Test @MainActor func pluginRegistryStoresPluginsPerInstance() {
    let first = KLinePluginRegistry()
    let second = KLinePluginRegistry()

    first.register(TestIndicatorPlugin())

    #expect(first.plugin(for: "test.scalar") != nil)
    #expect(second.plugin(for: "test.scalar") == nil)
}

@Test func indicatorSeriesStoreStoresAndReadsOpenKeySeries() {
    var store = IndicatorSeriesStore()
    let key = KLineSeriesKey(indicatorID: "test.scalar", name: "TEST")

    store.setValues(ContiguousArray<Double?>([1, nil, 3]), for: key)

    let values = store.values(for: key, as: Double.self)
    #expect(values == ContiguousArray<Double?>([1, nil, 3]))
}

@Test func legacyMACalculatorWritesOpenSeriesKey() async {
    let items: [any KLineItem] = [
        TestKLineItem(timestamp: 1, closing: 1),
        TestKLineItem(timestamp: 2, closing: 2),
        TestKLineItem(timestamp: 3, closing: 3)
    ]

    let store = await [MACalculator(period: 2).eraseToAnyIndicatorCalculator()].calculate(items: items)
    let values = store.values(for: KLineIndicator.Key.ma(2).kLineSeriesKey, as: Double.self)

    #expect(values?[0] == nil)
    #expect(values?[1] == 1.5)
    #expect(values?[2] == 2.5)
}

@Test @MainActor func defaultRegistryContainsBuiltInPlugins() {
    let registry = KLinePluginRegistry.default

    #expect(registry.plugin(for: KLineIndicator.ma.kLineID) != nil)
    #expect(registry.plugin(for: KLineIndicator.macd.kLineID) != nil)
}

@Test @MainActor func builtInMAPluginCreatesCalculatorsAndRenderers() {
    let plugin = KLinePluginRegistry.default.plugin(for: KLineIndicator.ma.kLineID)
    let configuration = KLineConfiguration()

    #expect(plugin?.defaultSeriesKeys == KLineIndicator.ma.defaultKeys.map(\.kLineSeriesKey))
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

@Test func dataPipelineMergesHistoricalPageIntoState() {
    var pipeline = DataPipeline()
    var state = ChartState()
    let items: [any KLineItem] = [
        TestKLineItem(timestamp: 60, closing: 1),
        TestKLineItem(timestamp: 120, closing: 2)
    ]

    pipeline.apply(.page(index: 0, items: items), to: &state)

    #expect(state.items.map(\.timestamp) == [60, 120])
}

@Test func dataPipelineMergesLiveTickIntoState() {
    var pipeline = DataPipeline()
    var state = ChartState(items: [
        TestKLineItem(timestamp: 60, closing: 1),
        TestKLineItem(timestamp: 120, closing: 2)
    ])

    pipeline.apply(.liveTick(TestKLineItem(timestamp: 120, closing: 22)), to: &state)

    #expect(state.items.map(\.closing) == [1, 22])
}

@Test @MainActor func indicatorPipelineNormalizesAndPersistsSelection() {
    let normalizer = IndicatorSelectionNormalizer(availableMain: [.ma, .ema], availableSub: [.vol])
    let store = InMemoryIndicatorSelectionStore()
    let pipeline = IndicatorPipeline(
        configuration: KLineConfiguration(defaultMainIndicators: [.ma], defaultSubIndicators: [.vol]),
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
    let registry = KLinePluginRegistry()
    registry.register(CloseEchoPlugin())
    let store = InMemoryIndicatorSelectionStore()
    let pipeline = IndicatorPipeline(
        configuration: KLineConfiguration(defaultMainIndicators: [.ma], defaultSubIndicators: [.vol]),
        normalizer: normalizer,
        selectionStore: store,
        registry: registry
    )

    let state = pipeline.setSelection(
        main: [.builtIn(.ma), .custom("custom.closeEcho")],
        sub: [.builtIn(.vol)]
    )

    #expect(state.main == [.builtIn(.ma), .custom("custom.closeEcho")])
    #expect(state.sub == [.builtIn(.vol)])
    #expect(state.mainIndicators == [.ma])
    #expect(store.savedState == state)
}

@Test @MainActor func renderPipelineUsesInstanceRegistry() {
    let firstRegistry = KLinePluginRegistry()
    let secondRegistry = KLinePluginRegistry()
    firstRegistry.registerRenderer(placement: .overlay) { _, _ in [TestRenderer()] }

    let factory = DescriptorFactory()
    let config = KLineConfiguration()
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

@Test @MainActor func chartControllerUpdatesContentStyleCommand() {
    var controller = ChartController(
        state: ChartState(),
        dataPipeline: DataPipeline(),
        indicatorPipeline: nil
    )

    controller.setChartContentStyle(.timeSeries)

    #expect(controller.state.contentStyle == .timeSeries)
}

private struct CloseEchoCalculator: KLineIndicatorCalculator {
    let id = KLineSeriesKey(indicatorID: "custom.closeEcho", name: "CloseEcho")

    func calculate(for items: [any KLineItem]) -> [Double?] {
        items.map { Optional($0.closing) }
    }
}

private struct CloseEchoPlugin: KLineIndicatorPlugin {
    let id: KLineIndicatorID = "custom.closeEcho"
    let title = "Close Echo"
    let placement = KLineIndicatorPlacement.main
    let defaultSeriesKeys = [KLineSeriesKey(indicatorID: "custom.closeEcho", name: "CloseEcho")]

    func makeCalculators(configuration: KLineConfiguration) -> [any KLineIndicatorCalculator] {
        [CloseEchoCalculator()]
    }

    @MainActor func makeRenderers(configuration: KLineConfiguration) -> [any KLineRenderer] {
        [RecordingRenderer()]
    }
}

private final class RecordingKLineItemProvider: KLineItemProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var liveStreamRequests = 0
    private var recoveryRequests = 0

    var liveStreamRequestCount: Int {
        lock.withLock { liveStreamRequests }
    }

    var recoveryRequestCount: Int {
        lock.withLock { recoveryRequests }
    }

    func fetchKLineItems(forPage page: Int) async throws -> [any KLineItem] {
        [
            TestKLineItem(timestamp: 60, closing: 1),
            TestKLineItem(timestamp: 120, closing: 2)
        ]
    }

    func fetchKLineItems(from start: Date, to end: Date) async throws -> [any KLineItem] {
        lock.withLock { recoveryRequests += 1 }
        return []
    }

    func liveStream() -> AsyncStream<any KLineItem> {
        lock.withLock { liveStreamRequests += 1 }
        return AsyncStream { continuation in
            continuation.finish()
        }
    }
}

@Test @MainActor func externalCustomIndicatorCanBeRegisteredCalculatedAndRendered() async {
    let registry = KLinePluginRegistry()
    registry.register(CloseEchoPlugin())
    let plugin = registry.plugin(for: "custom.closeEcho")
    let items: [any KLineItem] = [
        TestKLineItem(timestamp: 1, closing: 10),
        TestKLineItem(timestamp: 2, closing: 11)
    ]

    let calculators = plugin?.makeCalculators(configuration: KLineConfiguration()).map {
        $0.eraseToAnyIndicatorCalculator()
    } ?? []
    let store = await calculators.calculate(items: items)
    let values = store.values(for: KLineSeriesKey(indicatorID: "custom.closeEcho", name: "CloseEcho"), as: Double.self)

    #expect(values == ContiguousArray<Double?>([10, 11]))
    #expect(plugin?.makeRenderers(configuration: KLineConfiguration()).isEmpty == false)
}

@Test @MainActor func chartConfigurationIndicatorsDriveInitialViewSelection() {
    let chart = KLineChartConfiguration(
        appearance: .configuration(
            KLineConfiguration(
                defaultMainIndicators: [.ma],
                defaultSubIndicators: [.vol]
            )
        ),
        indicators: .init(main: [], sub: [.builtIn(.macd)]),
        features: []
    )

    let view = KLineView(chart: chart)

    #expect(view.debugSelectedBuiltInIndicators.main == [])
    #expect(view.debugSelectedBuiltInIndicators.sub == [.macd])
}

@Test @MainActor func persistedIndicatorSelectionOverridesChartConfigurationWhenEnabled() {
    let store = InMemoryIndicatorSelectionStore()
    store.savedState = KLineIndicatorSelectionState(mainIndicators: [.ema], subIndicators: [.rsi])
    let chart = KLineChartConfiguration(
        appearance: .configuration(
            KLineConfiguration(
                defaultMainIndicators: [.ma],
                defaultSubIndicators: [.vol]
            )
        ),
        indicators: .init(main: [], sub: [.builtIn(.macd)]),
        features: [.indicatorPersistence]
    )

    let view = KLineView(chart: chart, indicatorSelectionStore: store)

    #expect(view.debugSelectedBuiltInIndicators.main == [.ema])
    #expect(view.debugSelectedBuiltInIndicators.sub == [.rsi])
}

@Test @MainActor func chartConfigurationCanActivateCustomIndicator() {
    RecordingRenderer.installCount = 0
    let registry = KLinePluginRegistry()
    registry.register(CloseEchoPlugin())
    let chart = KLineChartConfiguration(
        indicators: .init(main: [.custom("custom.closeEcho")]),
        features: [],
        plugins: registry
    )

    _ = KLineView(chart: chart)

    #expect(RecordingRenderer.installCount == 1)
}

@Test @MainActor func customIndicatorAppearsInIndicatorTypeViewAndCanBeToggled() {
    let registry = KLinePluginRegistry()
    registry.register(CloseEchoPlugin())
    let chart = KLineChartConfiguration(
        indicators: .init(main: [], sub: []),
        features: [],
        plugins: registry
    )
    let view = KLineView(chart: chart)

    #expect(view.debugIndicatorTypeTitles.main.contains("Close Echo"))

    view.debugToggleIndicator(.custom("custom.closeEcho"), in: .mainChart)

    #expect(view.debugSelectedIndicators.main == [.custom("custom.closeEcho")])
}

@Test @MainActor func resetIndicatorsToDefaultUsesPipelineAndDropsCustomSelection() {
    let registry = KLinePluginRegistry()
    registry.register(CloseEchoPlugin())
    let store = InMemoryIndicatorSelectionStore()
    let chart = KLineChartConfiguration(
        appearance: .configuration(
            KLineConfiguration(
                defaultMainIndicators: [.ma],
                defaultSubIndicators: [.vol]
            )
        ),
        indicators: .init(main: [.custom("custom.closeEcho")], sub: []),
        features: [.indicatorPersistence],
        plugins: registry
    )
    let view = KLineView(chart: chart, indicatorSelectionStore: store)

    view.resetIndicatorsToDefault()

    #expect(view.debugSelectedIndicators.main == [.builtIn(.ma)])
    #expect(view.debugSelectedIndicators.sub == [.builtIn(.vol)])
    #expect(store.savedState?.main == [.builtIn(.ma)])
    #expect(store.savedState?.sub == [.builtIn(.vol)])
}

@Test @MainActor func drawSynchronizesControllerStateWithLegacyViewFields() async {
    let chart = KLineChartConfiguration(features: [])
    let view = KLineView(chart: chart)
    let items: [any KLineItem] = [
        TestKLineItem(timestamp: 60, closing: 1),
        TestKLineItem(timestamp: 120, closing: 2)
    ]

    await view.debugDraw(items: items)

    #expect(view.debugItemTimestamps == [60, 120])
    #expect(view.debugControllerItemTimestamps == [60, 120])
}

@Test func loaderDoesNotStartLiveStreamWhenLiveUpdatesAreDisabled() async throws {
    let provider = RecordingKLineItemProvider()
    let loader = KLineItemLoader(
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
    let provider = RecordingKLineItemProvider()
    let loader = KLineItemLoader(
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
