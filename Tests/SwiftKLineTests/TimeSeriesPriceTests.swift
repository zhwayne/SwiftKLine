#if canImport(UIKit)
import UIKit
import Testing
import SwiftKLineCore
@testable import SwiftKLineUI

private func priceMarkers(in view: UIView) -> [PriceMarkView] {
    ((view as? PriceMarkView).map { [$0] } ?? []) + view.subviews.flatMap { priceMarkers(in: $0) }
}

private func namedShape(_ name: String, in layer: CALayer) -> CAShapeLayer? {
    if layer.name == name, let shape = layer as? CAShapeLayer { return shape }
    return (layer.sublayers ?? []).lazy.compactMap { namedShape(name, in: $0) }.first
}

@Test @MainActor func timeSeriesLatestPriceHasGuideAndReturnControlWithoutExtremes() throws {
    let view = CanvasView(frame: CGRect(x: 0, y: 0, width: 200, height: 140))
    view.layoutIfNeeded()
    let scroll = ChartScrollView(frame: view.bounds)
    let dimensions = CandleDimensions(width: 8, gap: 2)
    let layout = ChartLayout(scrollView: scroll, candleDimensions: dimensions)
    layout.itemCount = 40
    layout.dataBounds = ValueBounds(min: 0, max: 100)
    let renderer = PriceIndicatorRenderer(style: PriceIndicatorStyle(), showsExtremes: false, latestPointColor: .blue)
    renderer.install(to: view.canvas)
    let items: [any ChartItem] = (0..<40).map { testCandle($0 * 60, Double($0 + 1)) }
    let context = ChartContext(seriesStore: IndicatorSeriesStore(), items: items,
        appearance: ChartAppearance(), candleDimensions: dimensions, visibleRange: 0..<20,
        layout: layout, location: nil, selectedIndex: 3)
    context.groupFrame = view.bounds
    context.viewPort = CGRect(x: 0, y: 20, width: 200, height: 100)
    renderer.draw(in: view.canvas, context: context)
    let marker = try #require(priceMarkers(in: view).first)
    #expect(marker.label.text == PriceFormatter().format(40 as NSNumber))
    #expect(marker.showArrow)
    let pointLayer = try #require(namedShape("latestPricePoint", in: view.canvas))
    #expect(pointLayer.path == nil)
    let labels = (view.canvas.sublayers ?? []).compactMap { $0 as? CATextLayer }
    #expect(labels.allSatisfy { $0.string == nil })
    let guide = try #require(view.canvas.sublayers?.last as? CAShapeLayer)
    #expect(guide.path?.boundingBoxOfPath.width == 200)
    #expect(guide.path?.boundingBoxOfPath.minY == 80)

    scroll.contentOffset.x = 200
    let latest = ChartContext(seriesStore: IndicatorSeriesStore(), items: items,
        appearance: ChartAppearance(), candleDimensions: dimensions, visibleRange: 20..<40,
        layout: layout, location: nil, selectedIndex: nil)
    latest.groupFrame = context.groupFrame
    latest.viewPort = context.viewPort
    renderer.draw(in: view.canvas, context: latest)
    #expect(!marker.showArrow)
    #expect(marker.label.text == PriceFormatter().format(40 as NSNumber))
    let dotBounds = try #require(pointLayer.path?.boundingBoxOfPath)
    let center = CGPoint(x: dotBounds.midX, y: dotBounds.midY)
    #expect(center == CGPoint(x: 194, y: 80))
    #expect(dotBounds.width == 6 && dotBounds.height == 6)
    #expect(pointLayer.fillColor == UIColor.blue.cgColor)
    #expect(pointLayer.strokeColor == nil)
    #expect(guide.path?.currentPoint == center)

    let priceCanvas = CALayer()
    priceCanvas.bounds = view.bounds
    let priceLine = TimeSeriesRenderer(style: TimeSeriesStyle(lineColor: .blue))
    priceLine.install(to: priceCanvas)
    priceLine.draw(in: priceCanvas, context: latest)
    #expect((priceCanvas.sublayers?[1] as? CAShapeLayer)?.path?.currentPoint == center)

    // Fractional horizontal scrolling moves the circle and dashed endpoint together.
    scroll.contentOffset.x = 200.5
    renderer.draw(in: view.canvas, context: latest)
    let scrolled = try #require(pointLayer.path?.boundingBoxOfPath)
    let expectedX = CGFloat(items.count - 1) * dimensions.itemWidth
        - scroll.contentOffset.x + dimensions.width * 0.5
    #expect(abs(scrolled.midX - expectedX) < 1e-8)
    #expect(guide.path?.currentPoint == CGPoint(x: scrolled.midX, y: scrolled.midY))
    renderer.draw(in: view.canvas, context: context)
    #expect(pointLayer.path == nil)
    renderer.uninstall(from: view.canvas)
    #expect(priceMarkers(in: view).isEmpty)
}

private final class TimeSeriesLivePriceProvider: ChartItemProvider, Sendable {
    let items: [any ChartItem]
    let stream: AsyncStream<any ChartItem>
    let continuation: AsyncStream<any ChartItem>.Continuation

    init(items: [any ChartItem]) {
        self.items = items
        (stream, continuation) = AsyncStream.makeStream()
    }
    func fetchChartItems(forPage page: Int) async throws -> [any ChartItem] { page == 0 ? items : [] }
    func fetchChartItems(from start: Date, to end: Date) async throws -> [any ChartItem] { [] }
    func liveStream() -> AsyncStream<any ChartItem> { stream }
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func latestPriceSurvivesModeSwitchesAndUpdatesWithLiveTicks() async throws {
    let items: [any ChartItem] = (0..<100).map { testCandle($0 * 60, 100 + Double($0 % 10)) }
    let provider = TimeSeriesLivePriceProvider(items: items)
    let factories = TestCounter()
    var configuration = try ChartConfiguration(source: CandleSource(id: "price-modes", duration: 60) {
        factories.increment()
        return provider
    }, features: [.liveUpdates])
    let chart = ChartView(configuration: configuration)
    defer { chart.shutdown(); provider.continuation.finish() }
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 500))
    let controller = UIViewController()
    window.rootViewController = controller
    controller.view.addSubview(chart)
    window.isHidden = false
    defer { window.isHidden = true }
    #expect(await eventually { chart.debugItemTimestamps.count == 100 })
    await chart.debugWaitForRefresh()
    chart.frame = CGRect(x: 0, y: 0, width: 390, height: chart.intrinsicContentSize.height)
    chart.scrollToLatest()
    _ = chart.debugRenderForInspection()
    #expect(priceMarkers(in: chart).count == 1)
    #expect(namedShape("latestPricePoint", in: chart.layer)?.path == nil)

    configuration.content = .timeSeries
    chart.apply(configuration)
    await chart.debugWaitForRefresh()
    _ = chart.debugRenderForInspection()
    #expect(priceMarkers(in: chart).count == 1)
    #expect(priceMarkers(in: chart).first?.label.text == PriceFormatter().format(109 as NSNumber))
    let point = try #require(namedShape("latestPricePoint", in: chart.layer))
    let guide = try #require(namedShape("latestPriceGuide", in: chart.layer))
    let initialBounds = try #require(point.path?.boundingBoxOfPath)
    #expect(guide.path?.currentPoint == CGPoint(x: initialBounds.midX, y: initialBounds.midY))

    provider.continuation.yield(testCandle(99 * 60, 123))
    #expect(await eventually { chart.debugRenderedCloses.last == 123 })
    _ = chart.debugRenderForInspection()
    #expect(priceMarkers(in: chart).first?.label.text == PriceFormatter().format(123 as NSNumber))
    let updatedBounds = try #require(point.path?.boundingBoxOfPath)
    #expect(guide.path?.currentPoint == CGPoint(x: updatedBounds.midX, y: updatedBounds.midY))
    #expect(updatedBounds.midY != initialBounds.midY)

    configuration.content = .candlestick
    chart.apply(configuration)
    await chart.debugWaitForRefresh()
    _ = chart.debugRenderForInspection()
    #expect(priceMarkers(in: chart).count == 1)
    #expect(priceMarkers(in: chart).first?.label.text == PriceFormatter().format(123 as NSNumber))
    #expect(namedShape("latestPricePoint", in: chart.layer)?.path == nil)
    #expect(factories.count == 1)
}
#endif
