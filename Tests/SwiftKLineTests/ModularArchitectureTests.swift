//
//  ModularArchitectureTests.swift
//  SwiftKLineTests
//
//  Created by zhwayne on 2026/10/21.
//

#if canImport(UIKit)
import UIKit
import SwiftKLine
import Testing
@testable import SwiftKLineUI
@testable import SwiftKLineCore

private func item(_ timestamp: Int, _ close: Double) -> Candle {
    Candle(timestamp: timestamp, open: close, high: 30, low: 0, close: close, volume: 10)
}

@Test @MainActor func timeSeriesInvalidatesWhenAnInteriorCandleChanges() {
    let scroll = ChartScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 150))
    let dimensions = CandleDimensions(width: 8, gap: 2)
    let layout = ChartLayout(scrollView: scroll, candleDimensions: dimensions)
    layout.itemCount = 3
    layout.dataBounds = ValueBounds(min: 0, max: 30)
    let renderer = TimeSeriesRenderer(style: TimeSeriesStyle())
    let layer = CALayer()
    layer.bounds = scroll.bounds
    renderer.install(to: layer)
    func context(_ closes: [Double], revision: UInt64) -> ChartContext {
        let context = ChartContext(indicatorSeriesStore: IndicatorSeriesStore(),
            items: closes.enumerated().map { item($0.offset * 60, $0.element) },
            appearance: ChartAppearance(), candleDimensions: dimensions, visibleRange: 0..<3,
            layout: layout, location: nil, selectedIndex: nil, dataRevision: revision)
        context.viewPort = layer.bounds
        context.groupFrame = layer.bounds
        return context
    }
    renderer.draw(in: layer, context: context([10, 15, 20], revision: 1))
    let oldHeight = (layer.sublayers?[1] as? CAShapeLayer)?.path?.boundingBoxOfPath.height
    renderer.draw(in: layer, context: context([10, 5, 20], revision: 2))
    let newHeight = (layer.sublayers?[1] as? CAShapeLayer)?.path?.boundingBoxOfPath.height
    #expect(abs((oldHeight ?? 0) - 50) < 1e-10)
    #expect(abs((newHeight ?? 0) - 75) < 1e-10)
}

@Test @MainActor func scalarRendererClearsUnavailableSeries() {
    let scroll = ChartScrollView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    let dims = CandleDimensions(width: 8, gap: 2)
    let layout = ChartLayout(scrollView: scroll, candleDimensions: dims)
    layout.itemCount = 2
    layout.dataBounds = ValueBounds(min: 0, max: 30)
    let renderer = LineIndicatorRenderer(series: [.ma(period: 1)])
    let layer = CALayer()
    renderer.install(to: layer)
    var store = IndicatorSeriesStore()
    store.setValues(ContiguousArray<Double?>([10, 20]), for: .ma(period: 1))
    func context(_ store: IndicatorSeriesStore) -> ChartContext {
        let ctx = ChartContext(indicatorSeriesStore: store, items: [item(0, 10), item(60, 20)],
            appearance: ChartAppearance(), candleDimensions: dims, visibleRange: 0..<2,
            layout: layout, location: nil, selectedIndex: nil)
        ctx.viewPort = scroll.bounds
        return ctx
    }
    renderer.draw(in: layer, context: context(store))
    #expect((layer.sublayers?.first as? CAShapeLayer)?.path != nil)
    renderer.draw(in: layer, context: context(IndicatorSeriesStore()))
    #expect((layer.sublayers?.first as? CAShapeLayer)?.path == nil)
}

@Test @MainActor func bandRendererDrawsChannelBoundsAndClearsMissingSeries() {
    let scroll = ChartScrollView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    let dimensions = CandleDimensions(width: 8, gap: 2)
    let layout = ChartLayout(scrollView: scroll, candleDimensions: dimensions)
    layout.itemCount = 3
    layout.dataBounds = ValueBounds(min: 0, max: 30)
    let key = SeriesKey.donchian(period: 2)
    let renderer = BandRenderer(key: key)
    let layer = CALayer()
    layer.bounds = scroll.bounds
    renderer.install(to: layer)

    var store = IndicatorSeriesStore()
    store.setValues(ContiguousArray<BandIndicatorValue?>([
        BandIndicatorValue(upper: 20, middle: 18, lower: 16),
        BandIndicatorValue(upper: 22, middle: 20, lower: 18),
        BandIndicatorValue(upper: 24, middle: 22, lower: 20)
    ]), for: key)
    let items: [any ChartItem] = (0..<3).map { item($0 * 60, 20) }
    func context(_ store: IndicatorSeriesStore) -> ChartContext {
        let ctx = ChartContext(indicatorSeriesStore: store, items: items,
            appearance: ChartAppearance(), candleDimensions: dimensions, visibleRange: 0..<3,
            layout: layout, location: nil, selectedIndex: nil)
        ctx.viewPort = scroll.bounds
        return ctx
    }

    renderer.draw(in: layer, context: context(store))
    #expect((layer.sublayers?[1] as? CAShapeLayer)?.path != nil)
    let bounds = renderer.dataBounds(context: context(store))
    #expect(bounds.min == 16 && bounds.max == 24)

    renderer.draw(in: layer, context: context(IndicatorSeriesStore()))
    #expect((layer.sublayers?[1] as? CAShapeLayer)?.path == nil)
}

@Test @MainActor func directionalAndIchimokuRenderersDrawAndClearMissingSeries() {
    let scroll = ChartScrollView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    let dimensions = CandleDimensions(width: 8, gap: 2)
    let layout = ChartLayout(scrollView: scroll, candleDimensions: dimensions)
    layout.itemCount = 4
    layout.dataBounds = ValueBounds(min: 0, max: 30)

    let superKey = SeriesKey.superTrend(period: 3, multiplier: 2)
    let ichimokuKey = SeriesKey.ichimoku(
        tenkanPeriod: 1, kijunPeriod: 2, senkouBPeriod: 2, displacement: 0
    )
    let superRenderer = SuperTrendRenderer(key: superKey)
    let ichimokuRenderer = IchimokuRenderer(key: ichimokuKey)
    let superLayer = CALayer()
    superLayer.bounds = scroll.bounds
    let ichimokuLayer = CALayer()
    ichimokuLayer.bounds = scroll.bounds
    superRenderer.install(to: superLayer)
    ichimokuRenderer.install(to: ichimokuLayer)

    var store = IndicatorSeriesStore()
    store.setValues(ContiguousArray<SuperTrendIndicatorValue?>([
        SuperTrendIndicatorValue(value: 18, isUp: true),
        SuperTrendIndicatorValue(value: 18, isUp: true),
        SuperTrendIndicatorValue(value: 24, isUp: false),
        SuperTrendIndicatorValue(value: 24, isUp: false)
    ]), for: superKey)
    store.setValues(ContiguousArray<IchimokuIndicatorValue?>([
        IchimokuIndicatorValue(tenkan: 10, kijun: 20, spanA: 16, spanB: 18, chikou: 15),
        IchimokuIndicatorValue(tenkan: 11, kijun: 21, spanA: 19, spanB: 17, chikou: 16),
        IchimokuIndicatorValue(tenkan: 12, kijun: 22, spanA: 20, spanB: 24, chikou: 17),
        IchimokuIndicatorValue(tenkan: 13, kijun: 23, spanA: 21, spanB: 25, chikou: 18)
    ]), for: ichimokuKey)

    func context(_ store: IndicatorSeriesStore) -> ChartContext {
        let ctx = ChartContext(indicatorSeriesStore: store, items: (0..<4).map { item($0 * 60, 20) },
            appearance: ChartAppearance(), candleDimensions: dimensions, visibleRange: 0..<4,
            layout: layout, location: nil, selectedIndex: nil)
        ctx.viewPort = scroll.bounds
        return ctx
    }

    superRenderer.draw(in: superLayer, context: context(store))
    ichimokuRenderer.draw(in: ichimokuLayer, context: context(store))
    let superPaths = (superLayer.sublayers ?? []).compactMap { ($0 as? CAShapeLayer)?.path }
    let ichimokuPaths = (ichimokuLayer.sublayers ?? []).compactMap { ($0 as? CAShapeLayer)?.path }
    #expect(superPaths.count == 4 && superPaths.allSatisfy { !$0.isEmpty })
    // A flip must not connect the two bands: each line layer stays at one price level.
    #expect(superPaths[2].boundingBoxOfPath.height == 0)
    #expect(superPaths[3].boundingBoxOfPath.height == 0)
    #expect(superPaths[2].boundingBoxOfPath.width > 0)
    #expect(superPaths[3].boundingBoxOfPath.width > 0)
    #expect(superPaths[0].boundingBoxOfPath.height > 0)
    #expect(superPaths[1].boundingBoxOfPath.height > 0)
    #expect(ichimokuPaths.count == 7 && ichimokuPaths.allSatisfy { !$0.isEmpty })
    #expect(superRenderer.dataBounds(context: context(store)).min == 18)
    #expect(superRenderer.dataBounds(context: context(store)).max == 24)
    #expect(ichimokuRenderer.dataBounds(context: context(store)).min == 10)
    #expect(ichimokuRenderer.dataBounds(context: context(store)).max == 25)

    superRenderer.draw(in: superLayer, context: context(IndicatorSeriesStore()))
    ichimokuRenderer.draw(in: ichimokuLayer, context: context(IndicatorSeriesStore()))
    #expect((superLayer.sublayers ?? []).allSatisfy { ($0 as? CAShapeLayer)?.path == nil })
    #expect((ichimokuLayer.sublayers ?? []).allSatisfy { ($0 as? CAShapeLayer)?.path == nil })
}

@Test @MainActor func superTrendRibbonsShadeEachCompleteTrendRun() {
    let scroll = ChartScrollView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    let dimensions = CandleDimensions(width: 8, gap: 2)
    let layout = ChartLayout(scrollView: scroll, candleDimensions: dimensions)
    layout.itemCount = 4
    layout.dataBounds = ValueBounds(min: 0, max: 30)
    let key = SeriesKey.superTrend(period: 3, multiplier: 2)
    let renderer = SuperTrendRenderer(key: key)
    let layer = CALayer()
    layer.bounds = scroll.bounds
    renderer.install(to: layer)

    var store = IndicatorSeriesStore()
    store.setValues(ContiguousArray<SuperTrendIndicatorValue?>([
        SuperTrendIndicatorValue(value: 18, isUp: true),
        SuperTrendIndicatorValue(value: 19, isUp: true),
        SuperTrendIndicatorValue(value: 20, isUp: false),
        SuperTrendIndicatorValue(value: 19, isUp: false)
    ]), for: key)
    let items: [any ChartItem] = [22, 23, 15, 14].enumerated().map { item($0.offset * 60, $0.element) }
    let ctx = ChartContext(
        indicatorSeriesStore: store,
        items: items,
        appearance: ChartAppearance(),
        candleDimensions: dimensions,
        visibleRange: 0..<4,
        layout: layout,
        location: nil,
        selectedIndex: nil
    )
    ctx.viewPort = scroll.bounds

    renderer.draw(in: layer, context: ctx)
    let paths = (layer.sublayers ?? []).compactMap { ($0 as? CAShapeLayer)?.path }
    #expect(paths.count == 4)
    #expect(!paths[0].isEmpty && !paths[1].isEmpty)
    #expect(!paths[2].isEmpty && !paths[3].isEmpty)
}

private actor LifecycleCounter {
    var pages = 0
    var streams = 0
    func recordPage() { pages += 1 }
    func recordStream() { streams += 1 }
}
private final class LifecycleProvider: ChartItemProvider, Sendable {
    let counter = LifecycleCounter()
    func fetchChartItems(forPage page: Int) async throws -> [any ChartItem] {
        await counter.recordPage()
        return []
    }
    func fetchChartItems(from start: Date, to end: Date) async throws -> [any ChartItem] { [] }
    func liveStream() -> AsyncStream<any ChartItem> {
        Task { await counter.recordStream() }
        return AsyncStream { $0.finish() }
    }
}

@Test func stopBeforeStartCannotCreateASubscription() async {
    let provider = LifecycleProvider()
    let loader = ChartItemLoader(provider: provider, eventHandler: { _ in })
    await loader.stop()
    await loader.start()
    await loader.willEnterForeground(latestTimestamp: 60)
    #expect(await provider.counter.pages == 0)
    #expect(await provider.counter.streams == 0)
}
@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1)), arguments: [CGFloat(390), CGFloat(1024)]) @MainActor
func offlineChartLaysOutAndDrawsFinitePaths(width: CGFloat) async throws {
    let candles = (0..<100).map { index in
        let price = 100 + sin(Double(index) * 0.3) * 10
        return Candle(timestamp: 1_700_000_000 + index * 60, open: price - 2,
                      high: price + 3, low: price - 3, close: price, volume: Double(100 + index % 10) * 10)
    }
    let chart = ChartView(configuration: try testConfiguration(items: candles,
        appearance: .themed(.solaris)),
        selection: testSelection(IndicatorSelection(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol, .macd])))
    chart.overrideUserInterfaceStyle = .light
    chart.backgroundColor = .white
    #expect(await eventually { chart.debugItemTimestamps.count == 100 })
    await chart.debugWaitForRefresh()
    chart.frame = CGRect(x: 0, y: 0, width: width, height: chart.intrinsicContentSize.height)
    chart.layoutIfNeeded()
    chart.scrollToLatest()
    let image = chart.debugRenderForInspection()
    #expect(abs(chart.debugViewportFrame.minX) < 1e-10)
    #expect(chart.debugViewportFrame.width == chart.bounds.width)
    func paths(in layer: CALayer) -> [CGPath] {
        let own = (layer as? CAShapeLayer)?.path.map { [$0] } ?? []
        return own + (layer.sublayers ?? []).flatMap { paths(in: $0) }
    }
    let drawn = paths(in: chart.layer).filter { !$0.isEmpty }
    #expect(drawn.count >= 10)
    #expect(drawn.allSatisfy { !$0.boundingBoxOfPath.isInfinite && !$0.boundingBoxOfPath.isNull })
    #expect(!chart.hasAmbiguousLayout)
    let png = try #require(image.pngData())
    // Keep the inspection artifact in the checkout's ignored build directory; simulator tmp is cleared on shutdown.
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let folder = root.appendingPathComponent(".build/validation")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let output = folder.appendingPathComponent("offline-chart-\(Int(width)).png")
    try png.write(to: output)
    if width == 390 { try png.write(to: folder.appendingPathComponent("offline-chart.png")) }
    print("SwiftKLine visual inspection: \(output.path)")
}

#endif
