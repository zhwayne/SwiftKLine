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
import SwiftKLine
import SwiftKLineCore
@testable import SwiftKLineUI

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func externalSelectionUsesPanelOnlyIntrinsicHeightAndGroupedMA() async throws {
    let selected = IndicatorSelection(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol, .macd])
    let candles = (0..<100).map { testCandle($0 * 60, Double($0)) }
    let appearance = ChartAppearance.themed(.solaris)
    let chart = ChartView(configuration: try testConfiguration(items: candles, appearance: appearance), indicators: selected)
    #expect(await eventually { chart.debugItemTimestamps.count == 100 })
    #expect(chart.indicators == selected)
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
    let chart = ChartView(configuration: try testConfiguration(items: candles), indicators: selected)
    #expect(await eventually { chart.debugItemTimestamps.count == 100 })
    #expect(chart.indicators == selected)

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
    let chart = ChartView(configuration: config, indicators: IndicatorSelection(mainIndicatorIDs: [.ma]))
    #expect(await eventually { chart.debugItemTimestamps.count == 1 })
    let renderer = try #require(chart.debugRenderer(for: "custom", as: TestRenderer.self))
    chart.setIndicators(IndicatorSelection())
    await chart.debugWaitForRefresh()
    #expect(chart.indicators.mainIndicatorIDs.isEmpty)
    #expect(chart.debugStore(for: "builtin.ma").values(for: .ma(period: 5), as: Double.self) == nil)
    chart.setIndicators(IndicatorSelection(mainIndicatorIDs: [.ma]))
    await chart.debugWaitForRefresh()
    #expect(chart.indicators.mainIndicatorIDs == [.ma])
    #expect(chart.debugRenderer(for: "custom", as: TestRenderer.self) === renderer)
    #expect(candleFactories.count == 1)
    #expect(coordinatorCreations.count == 1)
}

@Test @MainActor func selectionStillFiltersUnavailableMisplacedAndDuplicateIndicators() throws {
    let selection = IndicatorSelection(
        mainIndicatorIDs: [.ma, .vol, .ma, .ema, "custom.unavailable"],
        subIndicatorIDs: [.macd, .ema, .vol, .macd])
    let chart = ChartView(configuration: try testConfiguration(items: []),
                          indicators: selection)
    #expect(chart.indicators == selection)
    #expect(chart.resolvedIndicators.mainIndicatorIDs == [.ma, .ema])
    #expect(chart.resolvedIndicators.subIndicatorIDs == [.macd, .vol])
    chart.shutdown()
}

@Test @MainActor func originalTimeSeriesHidesBuiltInMainIndicatorsButAllowsCustomPagingOverlays() throws {
    let configuration = try testConfiguration(plugins: [TestPlugin(creations: TestCounter())], content: .timeSeries)
    let chart = ChartView(configuration: configuration, indicators: IndicatorSelection(mainIndicatorIDs: [.ma]))
    defer { chart.shutdown() }
    #expect(chart.indicators.mainIndicatorIDs == [.ma])
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

@Test @MainActor func visualChangesPreserveRequestedIndicators() throws {
    let requested = IndicatorSelection(mainIndicatorIDs: [.ma, .ema], subIndicatorIDs: [.vol])
    let chart = ChartView(configuration: try testConfiguration(), indicators: requested)
    defer { chart.shutdown() }
    chart.apply(try testConfiguration(appearance: .themed(.midnight)))
    #expect(chart.indicators == requested)
    #expect(chart.resolvedIndicators == requested)
    #expect(chart.debugVisiblePluginIDs.contains("builtin.ema"))
}

@Test @MainActor func emptyIndicatorsStayEmptyAcrossVisualUpdates() throws {
    let chart = ChartView(configuration: try testConfiguration(), indicators: IndicatorSelection())
    defer { chart.shutdown() }
    chart.apply(try testConfiguration(appearance: .themed(.solaris)))
    #expect(chart.resolvedIndicators == IndicatorSelection())
    chart.setIndicators(IndicatorSelection(mainIndicatorIDs: [.ma]))
    chart.apply(try testConfiguration())
    #expect(chart.indicators.mainIndicatorIDs == [.ma])
}
#endif
