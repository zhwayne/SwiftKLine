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

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor
func manualUpdatesKeepRenderersAndIndicatorsCoherent() async {
    let chart = ChartView(options: ChartOptions(
        indicators: IndicatorSelectionState(mainIndicatorIDs: [.ma]), features: []))
    await chart.debugWaitForRefresh()
    let identities = chart.debugRendererIdentities
    chart.setItems((0..<10).map { item($0 * 60, Double($0)) })
    await chart.debugWaitForRefresh()
    #expect(chart.debugRendererIdentities == identities)
    for i in 0..<100 { chart.update(item(540, Double(i))) }
    await chart.debugWaitForRefresh()
    #expect(chart.debugRenderedCloses.last == 99)
    #expect(chart.debugCoordinatorItemTimestamps == chart.debugItemTimestamps)
    #expect(chart.debugIndicatorSeriesStore.values(for: .ma(period: 5), as: Double.self)?.last! == (5 + 6 + 7 + 8 + 99) / 5.0)
    #expect(chart.debugRendererIdentities == identities)
    chart.setItems([])
    await chart.debugWaitForRefresh()
    #expect(chart.debugItemTimestamps.isEmpty)
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
            configuration: ChartConfiguration(), candleDimensions: dimensions, visibleRange: 0..<3,
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
            configuration: ChartConfiguration(), candleDimensions: dims, visibleRange: 0..<2,
            layout: layout, location: nil, selectedIndex: nil)
        ctx.viewPort = scroll.bounds
        return ctx
    }
    renderer.draw(in: layer, context: context(store))
    #expect((layer.sublayers?.first as? CAShapeLayer)?.path != nil)
    renderer.draw(in: layer, context: context(IndicatorSeriesStore()))
    #expect((layer.sublayers?.first as? CAShapeLayer)?.path == nil)
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
@Test(.timeLimit(.minutes(1))) @MainActor
func offlineChartLaysOutAndDrawsFinitePaths() async throws {
    let chart = ChartView(options: ChartOptions(appearance: .theme(.solaris),
        indicators: IndicatorSelectionState(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol, .macd]), features: []))
    chart.overrideUserInterfaceStyle = .light
    chart.backgroundColor = .white
    chart.setItems((0..<100).map { index in
        let price = 100 + sin(Double(index) * 0.3) * 10
        return Candle(timestamp: 1_700_000_000 + index * 60, open: price - 2,
                      high: price + 3, low: price - 3, close: price, volume: Double(100 + index % 10) * 10)
    })
    await chart.debugWaitForRefresh()
    chart.frame = CGRect(x: 0, y: 0, width: 390, height: chart.intrinsicContentSize.height)
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
    let output = folder.appendingPathComponent("offline-chart.png")
    try png.write(to: output)
    print("SwiftKLine visual inspection: \(output.path)")
}

#endif
