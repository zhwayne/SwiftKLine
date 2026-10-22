//
//  SelectorRestorationTests.swift
//  SwiftKLineTests
//
//  Created by zhwayne on 2026/10/21.
//

#if canImport(UIKit)
import UIKit
import Foundation
import Testing
import SwiftKLineCore
@testable import SwiftKLineUI

private final class MemorySelectionStore: IndicatorSelectionStore {
    var value: IndicatorSelectionState?
    var resets = 0
    init(_ value: IndicatorSelectionState?) { self.value = value }
    func load() -> IndicatorSelectionState? { value }
    func save(state: IndicatorSelectionState) { value = state }
    func reset() { value = nil; resets += 1 }
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func originalSelectorItemsLayoutAndGroupedMAArePreserved() async throws {
    let selected = IndicatorSelectionState(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol, .macd])
    let candles = (0..<100).map { testCandle($0 * 60, Double($0)) }
    let appearance = ChartAppearance.themed(.solaris)
    let chart = ChartView(configuration: try testConfiguration(items: candles, appearance: appearance, indicators: selected))
    #expect(await eventually { chart.debugItemTimestamps.count == 100 })
    #expect(chart.indicatorSelection == selected)
    #expect(chart.debugIndicatorTypeTitles.main == [
        "MA", "EMA", "WMA", "BOLL", "SAR", "BBI", "VWMA", "DONCHIAN", "SUPER", "ICHI"
    ])
    #expect(chart.debugIndicatorTypeTitles.sub == [
        "VOL", "RSI", "MACD", "KDJ", "CCI", "WR", "DMI", "ATR", "OBV", "ROC", "MFI", "TRIX"
    ])
    for period in [5, 10, 20] {
        #expect(chart.debugStore(for: "builtin.ma").values(for: .ma(period: period), as: Double.self)?.count == 100)
    }
    chart.frame = CGRect(x: 0, y: 0, width: 390, height: chart.intrinsicContentSize.height)
    _ = chart.debugRenderForInspection()
    #expect(chart.debugSelectorFrame.height == appearance.layoutMetrics.indicatorSelectorHeight)
    #expect(chart.debugSelectorFrame.maxY == chart.bounds.maxY)
    #expect(chart.debugViewportFrame.maxY == chart.debugSelectorFrame.minY)
    #expect(!chart.hasAmbiguousLayout)
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func newMainIndicatorsPublishTypedSeries() async throws {
    let selected = IndicatorSelectionState(
        mainIndicatorIDs: [.bbi, .vwma, .donchian, .superTrend, .ichimoku]
    )
    let candles = (0..<100).map { testCandle($0 * 60, Double($0 + 1)) }
    let chart = ChartView(configuration: try testConfiguration(items: candles, indicators: selected))
    #expect(await eventually { chart.debugItemTimestamps.count == 100 })
    #expect(chart.indicatorSelection == selected)

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
@Test(.timeLimit(.minutes(1))) @MainActor func selectorCommandsKeepCustomPluginStateAndCandleProvider() async throws {
    let candleFactories = TestCounter(), coordinatorCreations = TestCounter()
    let config = try ChartConfiguration(source: CandleSource(id: "candles", duration: 60) {
        candleFactories.increment(); return TestSnapshotProvider([testCandle(60, 10)])
    }, plugins: [TestPlugin(creations: coordinatorCreations)],
       indicators: IndicatorSelectionState(mainIndicatorIDs: [.ma]), features: [])
    let chart = ChartView(configuration: config)
    #expect(await eventually { chart.debugItemTimestamps.count == 1 })
    let renderer = try #require(chart.debugRenderer(for: "custom", as: TestRenderer.self))
    chart.debugToggleIndicator(.ma, in: .mainChart)
    await chart.debugWaitForRefresh()
    #expect(chart.indicatorSelection.mainIndicatorIDs.isEmpty)
    #expect(chart.debugStore(for: "builtin.ma").values(for: .ma(period: 5), as: Double.self) == nil)
    chart.debugToggleIndicator(.ma, in: .mainChart)
    await chart.debugWaitForRefresh()
    #expect(chart.indicatorSelection.mainIndicatorIDs == [.ma])
    #expect(chart.debugRenderer(for: "custom", as: TestRenderer.self) === renderer)
    #expect(candleFactories.count == 1)
    #expect(coordinatorCreations.count == 1)
}

@Test @MainActor func selectorStillFiltersUnavailableMisplacedAndDuplicateIndicators() throws {
    let appearance = ChartAppearance(indicators: [.ma, .ema, .vol, .macd])
    let selection = IndicatorSelectionState(
        mainIndicatorIDs: [.ma, .vol, .ma, .ema, "custom.unavailable"],
        subIndicatorIDs: [.macd, .ema, .vol, .macd])
    let chart = ChartView(configuration: try testConfiguration(items: [], appearance: appearance, indicators: selection))
    #expect(chart.indicatorSelection.mainIndicatorIDs == [.ma, .ema])
    #expect(chart.indicatorSelection.subIndicatorIDs == [.macd, .vol])
    chart.shutdown()
}

@Test @MainActor func originalPersistencePrecedenceAndResetArePreserved() throws {
    let saved = IndicatorSelectionState(mainIndicatorIDs: [.ema], subIndicatorIDs: [.rsi])
    let store = MemorySelectionStore(saved)
    let appearance = ChartAppearance(defaultMainIndicators: [.ma], defaultSubIndicators: [.vol])
    let config = try ChartConfiguration(source: CandleSource(id: "persisted", duration: 60) { SnapshotProvider(items: []) },
        appearance: appearance, indicators: IndicatorSelectionState(mainIndicatorIDs: [.ma], subIndicatorIDs: [.macd]),
        features: [.indicatorPersistence])
    let chart = ChartView(configuration: config, indicatorSelectionStore: store)
    #expect(chart.indicatorSelection == saved)
    chart.debugToggleIndicator(.ema, in: .mainChart)
    let changed = chart.indicatorSelection
    chart.apply(config)
    #expect(chart.indicatorSelection == changed)
    #expect(store.value == changed)
    chart.resetIndicatorsToDefault()
    #expect(chart.indicatorSelection == IndicatorSelectionState(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol]))
    #expect(store.value == chart.indicatorSelection)
    #expect(store.resets == 1)
}

@Test @MainActor func originalTimeSeriesHidesBuiltInMainIndicatorsButAllowsCustomPagingOverlays() throws {
    let config = try ChartConfiguration(source: CandleSource(id: "time-series", duration: 60) { SnapshotProvider(items: []) },
        content: .timeSeries, plugins: [TestPlugin(creations: TestCounter())],
        indicators: IndicatorSelectionState(mainIndicatorIDs: [.ma]), features: [])
    let chart = ChartView(configuration: config)
    #expect(chart.indicatorSelection.mainIndicatorIDs == [.ma])
    #expect(!chart.debugVisiblePluginIDs.contains("builtin.ma"))
    #expect(chart.debugVisiblePluginIDs.contains("custom"))
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func repeatedConfigurationPreservesCrosshairInspection() async throws {
    let config = try testConfiguration(items: (0..<100).map { testCandle($0 * 60, Double($0)) })
    let chart = ChartView(configuration: config)
    #expect(await eventually { chart.debugItemTimestamps.count == 100 })
    chart.frame = CGRect(x: 0, y: 0, width: 390, height: chart.intrinsicContentSize.height)
    _ = chart.debugRenderForInspection()
    chart.debugInspectCandle(at: 99)
    chart.apply(config)
    #expect(chart.debugSelectedCandleIndex == 99)
}
#endif
