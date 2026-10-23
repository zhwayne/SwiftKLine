//
//  SelectorRestorationTests.swift
//  SwiftKLineTests
//
//  Created by zhwayne on 2026/10/21.
//

#if canImport(UIKit)
import UIKit
import Foundation
import SwiftUI
import Testing
import SwiftKLine
import SwiftKLineCore
@testable import SwiftKLineUI

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func externalSelectionUsesPanelOnlyIntrinsicHeightAndGroupedMA() async throws {
    let selected = IndicatorSelection(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol, .macd])
    let candles = (0..<100).map { testCandle($0 * 60, Double($0)) }
    let appearance = ChartAppearance.themed(.solaris)
    let chart = ChartView(configuration: try testConfiguration(items: candles, appearance: appearance), selection: testSelection(selected))
    #expect(await eventually { chart.debugItemTimestamps.count == 100 })
    #expect(chart.selection.indicators == selected)
    for period in [5, 10, 20] {
        #expect(chart.debugStore(for: "builtin.ma").values(for: .ma(period: period), as: Double.self)?.count == 100)
    }
    let expectedHeight = appearance.layoutMetrics.mainChartHeight
        + appearance.layoutMetrics.timelineHeight
        + 2 * appearance.layoutMetrics.indicatorHeight
    #expect(chart.intrinsicContentSize.height == expectedHeight)
    chart.frame = CGRect(x: 0, y: 0, width: 390, height: expectedHeight)
    _ = chart.debugRenderForInspection()
    #expect(chart.debugViewportFrame.maxY == chart.bounds.maxY)
    #expect(!chart.hasAmbiguousLayout)
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func newMainIndicatorsPublishTypedSeries() async throws {
    let selected = IndicatorSelection(
        mainIndicatorIDs: [.bbi, .vwma, .donchian, .superTrend, .ichimoku]
    )
    let candles = (0..<100).map { testCandle($0 * 60, Double($0 + 1)) }
    let chart = ChartView(configuration: try testConfiguration(items: candles), selection: testSelection(selected))
    #expect(await eventually { chart.debugItemTimestamps.count == 100 })
    #expect(chart.selection.indicators == selected)

    let bbi = chart.debugStore(for: "builtin.bbi").values(for: .bbi, as: Double.self)
    let vwma = chart.debugStore(for: "builtin.vwma").values(for: .vwma(period: 20), as: Double.self)
    let donchian = chart.debugStore(for: "builtin.donchian").values(for: .donchian(period: 20), as: BandIndicatorValue.self)
    let superTrend = chart.debugStore(for: "builtin.super").values(
        for: .superTrend(period: 10, multiplier: 3),
        as: SuperTrendIndicatorValue.self
    )
    let ichimoku = chart.debugStore(for: "builtin.ichi").values(
        for: .ichimoku(tenkanPeriod: 9, kijunPeriod: 26, senkouBPeriod: 52, displacement: 26),
        as: IchimokuIndicatorValue.self
    )
    #expect(bbi?.count == 100 && bbi?[99] != nil)
    #expect(vwma?.count == 100 && vwma?[99] != nil)
    #expect(donchian?.count == 100 && donchian?[99] != nil)
    #expect(superTrend?.count == 100 && superTrend?[99] != nil)
    #expect(ichimoku?.count == 100 && ichimoku?[99]?.tenkan != nil && ichimoku?[99]?.spanB != nil)

    chart.frame = CGRect(x: 0, y: 0, width: 390, height: chart.intrinsicContentSize.height)
    _ = chart.debugRenderForInspection()
    chart.shutdown()
}

@MainActor private final class TestRenderer: ChartRenderer {
    let id = "custom"
    func install(to layer: CALayer) {}
    func uninstall(from layer: CALayer) {}
    func draw(in layer: CALayer, context: ChartContext) {}
}

@MainActor private struct TestPlugin: ChartPlugin {
    let id = "custom"
    let creations: TestCounter
    @MainActor final class Coordinator { let renderer = TestRenderer() }
    func makeCoordinator() -> Coordinator { creations.increment(); return Coordinator() }
    func update(coordinator: Coordinator, context: ChartPluginContext) {
        context.setRenderer(coordinator.renderer, for: "drawing", panel: .main)
    }
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func selectionCommandsKeepCustomPluginStateAndCandleProvider() async throws {
    let candleFactories = TestCounter(), coordinatorCreations = TestCounter()
    let config = try ChartConfiguration(source: CandleSource(id: "candles", duration: 60) {
        candleFactories.increment(); return TestSnapshotProvider([testCandle(60, 10)])
    }, plugins: [TestPlugin(creations: coordinatorCreations)],
       features: [])
    let chart = ChartView(configuration: config, selection: testSelection(IndicatorSelection(mainIndicatorIDs: [.ma])))
    #expect(await eventually { chart.debugItemTimestamps.count == 1 })
    let renderer = try #require(chart.debugRenderer(for: "custom", as: TestRenderer.self))
    chart.setSelection(testSelection(IndicatorSelection()))
    await chart.debugWaitForRefresh()
    #expect(chart.selection.indicators.mainIndicatorIDs.isEmpty)
    #expect(chart.debugStore(for: "builtin.ma").values(for: .ma(period: 5), as: Double.self) == nil)
    chart.setSelection(testSelection(IndicatorSelection(mainIndicatorIDs: [.ma])))
    await chart.debugWaitForRefresh()
    #expect(chart.selection.indicators.mainIndicatorIDs == [.ma])
    #expect(chart.debugRenderer(for: "custom", as: TestRenderer.self) === renderer)
    #expect(candleFactories.count == 1)
    #expect(coordinatorCreations.count == 1)
}

@Test @MainActor func selectionStillFiltersUnavailableMisplacedAndDuplicateIndicators() throws {
    let appearance = ChartAppearance(indicators: [.ma, .ema, .vol, .macd])
    let selection = IndicatorSelection(
        mainIndicatorIDs: [.ma, .vol, .ma, .ema, "custom.unavailable"],
        subIndicatorIDs: [.macd, .ema, .vol, .macd])
    let chart = ChartView(configuration: try testConfiguration(items: [], appearance: appearance),
                          selection: testSelection(selection))
    #expect(chart.selection.indicators.mainIndicatorIDs == [.ma, .ema])
    #expect(chart.selection.indicators.subIndicatorIDs == [.macd, .vol])
    chart.shutdown()
}

@Test @MainActor func sharedStoreSelectionPrecedenceAndResetDefaultsArePreserved() throws {
    let saved = testSelection(IndicatorSelection(mainIndicatorIDs: [.ema], subIndicatorIDs: [.rsi]), period: .oneHour)
    let store = MemoryChartStateStore()
    store.set(saved, for: .chartSelection)
    let appearance = ChartAppearance(defaultMainIndicators: [.ma], defaultSubIndicators: [.vol])
    let config = try testConfiguration(appearance: appearance)
    let initial = testSelection(IndicatorSelection(mainIndicatorIDs: [.ma], subIndicatorIDs: [.macd]))
    let chart = ChartView(configuration: config, selection: initial, stateStore: store)
    defer { chart.shutdown() }
    #expect(chart.selection == saved)
    let changed = testSelection(IndicatorSelection(subIndicatorIDs: [.rsi]), period: .fiveMinutes)
    chart.setSelection(changed)
    chart.apply(config)
    #expect(chart.selection == changed)
    #expect(store.value(for: .chartSelection) == changed)
    chart.resetSelectionToDefault()
    let defaults = testSelection(IndicatorSelection(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol]))
    #expect(chart.selection == defaults)
    #expect(store.value(for: .chartSelection) == defaults)
}

@Test @MainActor func applyingConfigurationReportsAndPersistsNormalizedSelectionOnce() throws {
    let store = MemoryChartStateStore()
    let initial = testSelection(IndicatorSelection(mainIndicatorIDs: [.ma, .ema], subIndicatorIDs: [.vol]))
    let configuration = try testConfiguration(appearance: ChartAppearance(indicators: [.ma, .ema, .vol]))
    let chart = ChartView(selection: initial, availablePeriods: [.oneMinute, .fiveMinutes],
                          stateStore: store, configuration: { _ in configuration })
    defer { chart.shutdown() }
    var reported: [ChartSelection] = []
    chart.selectionChanged = { reported.append($0) }

    let reduced = try testConfiguration(appearance: ChartAppearance(indicators: [.ma, .vol]))
    chart.apply(availablePeriods: [.fiveMinutes], configuration: { _ in reduced })
    let normalized = testSelection(IndicatorSelection(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol]), period: .fiveMinutes)
    #expect(chart.selection == normalized)
    #expect(reported == [normalized])
    #expect(store.value(for: .chartSelection) == normalized)
    chart.apply(availablePeriods: [.fiveMinutes], configuration: { _ in reduced })
    chart.setSelection(normalized)
    #expect(reported == [normalized])
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func swiftUISelectionHydratesBothFieldsAndKeepsProviderSessionsStable() async throws {
    let factories = TestCounter()
    let store = RecordingSelectionStore()
    let persisted = testSelection(IndicatorSelection(mainIndicatorIDs: [.ema], subIndicatorIDs: [.rsi]), period: .oneHour)
    store.set(persisted, for: .chartSelection)
    let model = SelectionBindingModel(testSelection(IndicatorSelection(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol])))
    let host = UIHostingController(rootView: SelectionBindingHost(model: model, store: store, factories: factories))
    let window = showSelectionHost(host)
    defer { window.isHidden = true }

    #expect(await eventually { model.selection == persisted })
    let chart = try #require(descendant(of: host.view, as: ChartView.self))
    #expect(await eventually { chart.debugItemTimestamps == [ChartPeriod.oneHour.seconds] })
    #expect(factories.count == 1)

    model.selection.period = .fiveMinutes
    #expect(await eventually {
        chart.selection == model.selection && store.value(for: .chartSelection) == model.selection
            && chart.debugItemTimestamps == [ChartPeriod.fiveMinutes.seconds]
    })
    #expect(factories.count == 2)
    model.selection.indicators = IndicatorSelection(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol])
    #expect(await eventually { chart.selection == model.selection && store.value(for: .chartSelection) == model.selection })
    #expect(factories.count == 2)

    model.selection = ChartSelection(period: ChartPeriod(seconds: -1, identifier: "invalid"),
        indicators: IndicatorSelection(mainIndicatorIDs: [.ma, .ma, .vol], subIndicatorIDs: [.ema, .vol, .vol, "invalid"]))
    let normalized = testSelection(IndicatorSelection(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol]))
    #expect(await eventually {
        model.selection == normalized && chart.selection == normalized && store.value(for: .chartSelection) == normalized
    })
    #expect(factories.count == 3)
    let writes = store.writes
    model.refreshToken += 1
    for _ in 0..<20 { await Task.yield() }
    #expect(factories.count == 3)
    #expect(store.writes == writes)

    let command = testSelection(IndicatorSelection(), period: .oneHour)
    chart.setSelection(command)
    #expect(await eventually { model.selection == command && store.value(for: .chartSelection) == command })
    #expect(factories.count == 4)

    chart.resetSelectionToDefault()
    let reset = testSelection(IndicatorSelection())
    #expect(await eventually {
        model.selection == reset && store.value(for: .chartSelection) == reset && chart.debugItemTimestamps == [60]
    })
    #expect(factories.count == 5)
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func swiftUIAvailabilityChangesNormalizeAndPublishBothFields() async throws {
    let factories = TestCounter()
    let store = MemoryChartStateStore()
    let model = SelectionBindingModel(testSelection(IndicatorSelection(mainIndicatorIDs: [.ema], subIndicatorIDs: [.rsi]), period: .oneHour))
    let host = UIHostingController(rootView: SelectionBindingHost(model: model, store: store, factories: factories))
    let window = showSelectionHost(host)
    defer { window.isHidden = true }
    let chart = try #require(descendant(of: host.view, as: ChartView.self))
    #expect(await eventually { factories.count == 1 })
    model.availablePeriods = [.fiveMinutes]
    model.appearance = ChartAppearance(indicators: [.ma, .vol])
    let normalized = testSelection(IndicatorSelection(), period: .fiveMinutes)
    #expect(await eventually {
        model.selection == normalized && chart.selection == normalized && store.value(for: .chartSelection) == normalized
    })
    #expect(factories.count == 2)
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func swiftUIBindingWorksWithoutStoreAndCanonicalizesPeriodBeforeSourceCreation() async throws {
    let factories = TestCounter()
    let initial = testSelection(IndicatorSelection(mainIndicatorIDs: [.ma, .ma]),
        period: ChartPeriod(seconds: 999, identifier: ChartPeriod.fiveMinutes.identifier))
    let model = SelectionBindingModel(initial)
    let host = UIHostingController(rootView: SelectionBindingHost(model: model, store: nil, factories: factories))
    let window = showSelectionHost(host)
    defer { window.isHidden = true }
    let normalized = testSelection(IndicatorSelection(mainIndicatorIDs: [.ma]), period: .fiveMinutes)
    #expect(await eventually { model.selection == normalized })
    let chart = try #require(descendant(of: host.view, as: ChartView.self))
    #expect(await eventually { chart.debugItemTimestamps == [300] })
    #expect(factories.count == 1)
    model.selection.period = .oneHour
    #expect(await eventually { chart.selection.period == .oneHour && factories.count == 2 })
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func swiftUIHydrationDoesNotOverwriteANewerExternalSelection() async throws {
    let factories = TestCounter()
    let store = MemoryChartStateStore()
    store.set(testSelection(IndicatorSelection(mainIndicatorIDs: [.ema]), period: .oneHour), for: .chartSelection)
    let model = SelectionBindingModel(testSelection(IndicatorSelection(mainIndicatorIDs: [.ma])))
    let host = UIHostingController(rootView: SelectionBindingHost(model: model, store: store, factories: factories))
    let window = showSelectionHost(host)
    defer { window.isHidden = true }
    let chart = try #require(descendant(of: host.view, as: ChartView.self))
    let latest = testSelection(IndicatorSelection(subIndicatorIDs: [.rsi]), period: .fiveMinutes)
    // Issue a command before the initial asynchronous hydration write gets a chance to execute.
    model.selection = latest
    #expect(await eventually {
        model.selection == latest && chart.selection == latest && store.value(for: .chartSelection) == latest
    })
    #expect(factories.count == 2)
}

@Test @MainActor func emptyStoredIndicatorSelectionWinsOverDefaultsAndLegacyRecord() throws {
    let store = MemoryChartStateStore()
    let empty = testSelection(IndicatorSelection(), period: .fiveMinutes)
    store.set(empty, for: .chartSelection)
    store.set(IndicatorSelection(mainIndicatorIDs: [.ema]), for: ChartStateKey<IndicatorSelection>("indicator.selection"))
    let configuration = try testConfiguration(appearance:
        ChartAppearance(defaultMainIndicators: [.ma], defaultSubIndicators: [.vol]))
    let chart = ChartView(configuration: configuration, stateStore: store)
    defer { chart.shutdown() }
    #expect(chart.selection == empty)
    #expect(store.value(for: .chartSelection) == empty)
}

@Test @MainActor func builtInStateStoresRoundTripTypedValues() throws {
    let periodKey = ChartStateKey<String>("test.period")
    let memory = MemoryChartStateStore()
    memory.set("5m", for: periodKey)
    #expect(memory.value(for: periodKey) == "5m")
    #expect(MemoryChartStateStore().value(for: periodKey) == nil)
    memory.removeValue(for: periodKey)
    #expect(memory.value(for: periodKey) == nil)

    let suiteName = "SwiftKLineTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsChartStateStore(defaults: defaults)
    store.set("1h", for: periodKey)
    #expect(store.value(for: periodKey) == "1h")
    store.removeValue(for: periodKey)
    #expect(store.value(for: periodKey) == nil)
    let unprefixed = UserDefaultsChartStateStore(defaults: defaults, namespace: "")
    unprefixed.set("4h", for: periodKey)
    #expect(defaults.data(forKey: periodKey.rawValue) != nil)
    #expect(unprefixed.value(for: periodKey) == "4h")
    unprefixed.removeValue(for: periodKey)
    #expect(defaults.data(forKey: periodKey.rawValue) == nil)
}

@Test @MainActor func userDefaultsNamespacesIsolateAndRestoreWholeChartSelections() throws {
    let suiteName = "SwiftKLineTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let firstStore = UserDefaultsChartStateStore(defaults: defaults, namespace: "chart.first")
    let secondStore = UserDefaultsChartStateStore(defaults: defaults, namespace: "chart.second")
    let configuration = try testConfiguration()
    let first = ChartView(configuration: configuration, stateStore: firstStore)
    let second = ChartView(configuration: configuration, stateStore: secondStore)
    defer { first.shutdown(); second.shutdown() }
    let firstSelection = testSelection(IndicatorSelection(mainIndicatorIDs: [.ema], subIndicatorIDs: [.rsi]), period: .fiveMinutes)
    let secondSelection = testSelection(IndicatorSelection(mainIndicatorIDs: [.ma], subIndicatorIDs: [.macd]), period: .oneHour)
    first.setSelection(firstSelection)
    second.setSelection(secondSelection)
    let restoredFirst = ChartView(configuration: configuration,
        stateStore: UserDefaultsChartStateStore(defaults: defaults, namespace: "chart.first"))
    let restoredSecond = ChartView(configuration: configuration,
        stateStore: UserDefaultsChartStateStore(defaults: defaults, namespace: "chart.second"))
    defer { restoredFirst.shutdown(); restoredSecond.shutdown() }
    #expect(restoredFirst.selection == firstSelection)
    #expect(restoredSecond.selection == secondSelection)
    restoredFirst.resetSelectionToDefault()
    #expect(secondStore.value(for: .chartSelection) == secondSelection)
}

@Test @MainActor func defaultNamespaceMigratesLegacyIndicatorDataIntoUnifiedSelection() throws {
    let suiteName = "SwiftKLineTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let saved = IndicatorSelection(mainIndicatorIDs: [.ema], subIndicatorIDs: [.rsi])
    defaults.set(try PropertyListEncoder().encode(saved), forKey: "com.swiftkline.indicator.selection")
    let store = UserDefaultsChartStateStore(defaults: defaults)
    let initial = testSelection(IndicatorSelection(), period: .fiveMinutes)
    let chart = ChartView(configuration: try testConfiguration(), selection: initial, stateStore: store)
    defer { chart.shutdown() }
    #expect(chart.selection == testSelection(saved, period: .fiveMinutes))
    let data = try #require(defaults.data(forKey: "com.swiftkline.chart.selection"))
    #expect(try JSONDecoder().decode(ChartSelection.self, from: data) == chart.selection)
}

@Test @MainActor func originalTimeSeriesHidesBuiltInMainIndicatorsButAllowsCustomPagingOverlays() throws {
    let configuration = try testConfiguration(plugins: [TestPlugin(creations: TestCounter())], content: .timeSeries)
    let chart = ChartView(configuration: configuration, selection: testSelection(IndicatorSelection(mainIndicatorIDs: [.ma])))
    defer { chart.shutdown() }
    #expect(chart.selection.indicators.mainIndicatorIDs == [.ma])
    #expect(!chart.debugVisiblePluginIDs.contains("builtin.ma"))
    #expect(chart.debugVisiblePluginIDs.contains("custom"))
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func repeatedConfigurationPreservesCrosshairInspection() async throws {
    let config = try testConfiguration(items: (0..<100).map { testCandle($0 * 60, Double($0)) })
    let chart = ChartView(configuration: config)
    defer { chart.shutdown() }
    #expect(await eventually { chart.debugItemTimestamps.count == 100 })
    chart.frame = CGRect(x: 0, y: 0, width: 390, height: chart.intrinsicContentSize.height)
    _ = chart.debugRenderForInspection()
    chart.debugInspectCandle(at: 99)
    chart.apply(config)
    #expect(chart.debugSelectedCandleIndex == 99)
}

@MainActor
private final class SelectionBindingModel: ObservableObject {
    @Published var selection: ChartSelection
    @Published var availablePeriods: [ChartPeriod] = [.oneMinute, .fiveMinutes, .oneHour]
    @Published var appearance = ChartAppearance(indicators: [.ma, .ema, .vol, .rsi])
    @Published var refreshToken = 0
    init(_ selection: ChartSelection) { self.selection = selection }
}

@MainActor
private final class RecordingSelectionStore: ChartStateStore {
    private let memory = MemoryChartStateStore()
    private(set) var writes = 0
    func data(forKey key: String) -> Data? { memory.data(forKey: key) }
    func set(_ data: Data, forKey key: String) { writes += 1; memory.set(data, forKey: key) }
    func removeValue(forKey key: String) { memory.removeValue(forKey: key) }
}

@available(iOS 16.0, *)
private struct SelectionBindingHost: View {
    @ObservedObject var model: SelectionBindingModel
    let store: (any ChartStateStore)?
    let factories: TestCounter

    var body: some View {
        let _ = model.refreshToken
        KLineChart(selection: $model.selection, availablePeriods: model.availablePeriods, stateStore: store) { selection in
            let period = selection.period
            let source = CandleSource(id: "\(period.identifier):\(period.seconds)", duration: Double(period.seconds)) {
                factories.increment()
                return TestSnapshotProvider([testCandle(period.seconds, 10)])
            }
            return try! ChartConfiguration(source: source, appearance: model.appearance, features: [])
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

@MainActor
private func showSelectionHost<Content: View>(_ host: UIHostingController<Content>) -> UIWindow {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.frame = window.bounds
    host.view.layoutIfNeeded()
    return window
}

@MainActor
private func descendant<ViewType: UIView>(of view: UIView, as type: ViewType.Type) -> ViewType? {
    if let match = view as? ViewType { return match }
    for subview in view.subviews {
        if let match = descendant(of: subview, as: type) { return match }
    }
    return nil
}
#endif
