#if canImport(UIKit)
import UIKit
import Testing
import SwiftKLineCore
@testable import SwiftKLineUI

@Test @MainActor func timeSeriesFillFadesVerticallyInsideThePriceArea() throws {
    let scroll = ChartScrollView(frame: CGRect(x: 0, y: 0, width: 140, height: 140))
    let dimensions = CandleDimensions(width: 8, gap: 112)
    let layout = ChartLayout(scrollView: scroll, candleDimensions: dimensions)
    layout.itemCount = 2
    layout.dataBounds = ValueBounds(min: 0, max: 100)
    let renderer = TimeSeriesRenderer(style: TimeSeriesStyle(
        lineColor: .blue, fillColor: UIColor.blue.withAlphaComponent(0.8), borderColor: .clear
    ))
    let canvas = CALayer()
    canvas.bounds = scroll.bounds
    renderer.install(to: canvas)
    let viewport = CGRect(x: 0, y: 20, width: 140, height: 80)
    func context(items: [any ChartItem], revision: UInt64) -> ChartContext {
        let ctx = ChartContext(seriesStore: IndicatorSeriesStore(), items: items,
            appearance: ChartAppearance(), candleDimensions: dimensions, visibleRange: 0..<items.count,
            layout: layout, location: nil, selectedIndex: nil, dataRevision: revision)
        ctx.groupFrame = canvas.bounds
        ctx.viewPort = viewport
        return ctx
    }
    let candles: [any ChartItem] = [testCandle(0, 80), testCandle(60, 80)]
    let ctx = context(items: candles, revision: 1)
    renderer.draw(in: canvas, context: ctx)
    let gradient = try #require(canvas.sublayers?.first as? CAGradientLayer)
    let mask = try #require(gradient.mask as? CAShapeLayer)
    #expect(gradient.frame == viewport)
    #expect(gradient.startPoint == CGPoint(x: 0.5, y: 0))
    #expect(gradient.endPoint == CGPoint(x: 0.5, y: 1))
    #expect(abs((mask.path?.boundingBoxOfPath.minY ?? 0) - 16) < 1e-8)

    let pixelWidth = 140, pixelHeight = 140
    var pixels = [UInt8](repeating: 0, count: pixelWidth * pixelHeight * 4)
    try pixels.withUnsafeMutableBytes { storage in
        let bitmap = try #require(CGContext(data: storage.baseAddress,
            width: pixelWidth, height: pixelHeight, bitsPerComponent: 8, bytesPerRow: pixelWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        bitmap.translateBy(x: 0, y: CGFloat(pixelHeight))
        bitmap.scaleBy(x: 1, y: -1)
        canvas.render(in: bitmap)
    }
    func alpha(x: Int, y: Int) -> UInt8 { pixels[(y * pixelWidth + x) * 4 + 3] }
    #expect(alpha(x: 60, y: 45) > alpha(x: 60, y: 90))
    #expect(alpha(x: 60, y: 90) > 0)
    #expect(alpha(x: 60, y: 99) < 8)
    #expect(alpha(x: 60, y: 25) == 0)
    #expect(alpha(x: 60, y: 110) == 0)

    let identity = ObjectIdentifier(gradient)
    renderer.updateStyle(TimeSeriesStyle(fillColor: UIColor.red.withAlphaComponent(0.6)))
    renderer.draw(in: canvas, context: ctx)
    #expect(ObjectIdentifier(try #require(canvas.sublayers?.first)) == identity)
    let colors = try #require(gradient.colors as? [CGColor])
    #expect(colors.first == UIColor.red.withAlphaComponent(0.6).cgColor)
    #expect(colors.last?.alpha == 0)

    scroll.contentOffset.x = 40
    renderer.draw(in: canvas, context: ctx)
    #expect(abs((mask.path?.boundingBoxOfPath.minX ?? 0) + 36) < 1e-8)
    #expect(gradient.frame == viewport)
    renderer.draw(in: canvas, context: context(items: [], revision: 2))
    #expect(mask.path == nil)
    #expect((canvas.sublayers?[1] as? CAShapeLayer)?.path == nil)
    renderer.uninstall(from: canvas)
    #expect(canvas.sublayers?.isEmpty != false)
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1)), arguments: [CGFloat(390), CGFloat(1024)]) @MainActor
func timeSeriesGradientRendersAtPhoneAndTabletWidths(width: CGFloat) async throws {
    let items: [any ChartItem] = (0..<120).map { i in
        testCandle(i * 60, 100 + sin(Double(i) * 0.15) * 12)
    }
    let chart = ChartView(configuration: try testConfiguration(items: items, content: .timeSeries))
    defer { chart.shutdown() }
    #expect(await eventually { chart.debugItemTimestamps.count == 120 })
    await chart.debugWaitForRefresh()
    chart.backgroundColor = .white
    chart.overrideUserInterfaceStyle = .light
    chart.frame = CGRect(x: 0, y: 0, width: width, height: chart.intrinsicContentSize.height)
    chart.scrollToLatest()
    let image = chart.debugRenderForInspection()
    func gradients(in layer: CALayer) -> [CAGradientLayer] {
        ((layer as? CAGradientLayer).map { [$0] } ?? []) + (layer.sublayers ?? []).flatMap { gradients(in: $0) }
    }
    #expect(gradients(in: chart.layer).contains { $0.mask is CAShapeLayer })
    #expect(!chart.hasAmbiguousLayout)
    let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".build/validation")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try #require(image.pngData()).write(to: folder.appendingPathComponent("time-series-gradient-\(Int(width)).png"))
}
#endif
