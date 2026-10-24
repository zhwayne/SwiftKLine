#if canImport(UIKit)
import Foundation
import UIKit
import Testing
import SwiftKLineCore
import SwiftKLine
@testable import SwiftKLineUI

private let additionalIndicators: [BuiltInIndicator] = [.kdj, .cci, .wr, .dmi, .atr, .obv, .roc, .mfi, .trix]

/// Compile the public-API example used verbatim by both configuration guides.
@Test @MainActor func subIndicatorConfigurationGuideCompilesAgainstPublicExports() {
    let kdjKey = SeriesKey.kdj(period: 9, kPeriod: 3, dPeriod: 3)
    let dmiKey = SeriesKey.dmi(diPeriod: 14, adxPeriod: 14)
    let appearance = ChartAppearance(
        indicatorStyleRegistry: [
            kdjKey: KDJStyle(kColor: .systemOrange, dColor: .systemBlue, jColor: .systemPurple),
            dmiKey: DMIStyle(plusDIColor: .systemGreen, minusDIColor: .systemRed, adxColor: .systemOrange),
            .wr(period: 14): LineStyle(strokeColor: .systemBlue),
            .wr(period: 7): LineStyle(strokeColor: .systemPurple)
        ]
    )
    let parameters = IndicatorConfiguration(seriesKeys: [
        .kdj: [kdjKey],
        .dmi: [dmiKey],
        .wr: [.wr(period: 14), .wr(period: 7)]
    ])
    let selection = IndicatorSelection(subIndicatorIDs: [.kdj, .dmi, .wr])
    #expect(parameters.indicatorKeys(for: .wr).count == 2)
    #expect(appearance.indicatorStyle(for: kdjKey, type: KDJStyle.self) != nil)
    #expect(selection.subIndicatorIDs == [.kdj, .dmi, .wr])
}

private func allLayers(_ layer: CALayer) -> [CALayer] {
    [layer] + (layer.sublayers ?? []).flatMap(allLayers)
}

@Test @MainActor func subIndicatorLegendUsesOwningViewScaleAndTracksChanges() throws {
    let view = CanvasView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    view.contentScaleFactor = 3
    view.layoutIfNeeded()
    #expect(view.canvas.contentsScale == 1)
    let renderer = SubIndicatorRenderer.make(key: .kdj(period: 9, kPeriod: 3, dPeriod: 3))
    renderer.install(to: view.canvas)
    let legend = try #require(view.canvas.sublayers?.compactMap { $0 as? CATextLayer }.first)
    #expect(legend.contentsScale == 3)

    let scroll = ChartScrollView(frame: view.bounds)
    let dimensions = CandleDimensions(width: 8, gap: 2)
    let layout = ChartLayout(scrollView: scroll, candleDimensions: dimensions)
    let context = ChartContext(seriesStore: IndicatorSeriesStore(), items: [],
        appearance: ChartAppearance(), candleDimensions: dimensions, visibleRange: 0..<0,
        layout: layout, location: nil, selectedIndex: nil)
    context.legendText = NSAttributedString(string: "KDJ(9,3,3) K:87.59")
    context.legendFrame = view.bounds
    view.contentScaleFactor = 2
    renderer.updateLegend(context: context)
    #expect(legend.contentsScale == 2)
    #expect((legend.string as? NSAttributedString)?.string == context.legendText?.string)

    let window = UIWindow(frame: view.bounds)
    let controller = UIViewController()
    window.rootViewController = controller
    controller.view.addSubview(view)
    window.isHidden = false
    defer { window.isHidden = true }
    #expect(view.window === window)
    view.contentScaleFactor = 1
    renderer.updateLegend(context: context)
    #expect(legend.contentsScale == window.screen.scale)
    renderer.uninstall(from: view.canvas)
}

@Test @MainActor func subRendererBreaksGapsClearsAndKeepsJExtremes() {
    let key = SeriesKey.kdj(period: 2, kPeriod: 3, dPeriod: 3)
    let renderer = SubIndicatorRenderer.make(key: key)
    let layer = CALayer()
    layer.bounds = CGRect(x: 0, y: 0, width: 200, height: 100)
    renderer.install(to: layer)
    let identities = (layer.sublayers ?? []).map(ObjectIdentifier.init)
    let scroll = ChartScrollView(frame: layer.bounds)
    let dimensions = CandleDimensions(width: 8, gap: 2)
    let layout = ChartLayout(scrollView: scroll, candleDimensions: dimensions)
    layout.itemCount = 5
    layout.dataBounds = ValueBounds(min: -30, max: 150)
    let items: [any ChartItem] = (0..<5).map { testCandle($0 * 60, 20) }
    var store = IndicatorSeriesStore()
    store.setValues(ContiguousArray<KDJIndicatorValue?>([
        .init(k: 20, d: 40, j: -20), .init(k: 30, d: 40, j: 10), nil,
        .init(k: 90, d: 60, j: 150), .init(k: 80, d: 65, j: 110)
    ]), for: key)
    func context(_ store: IndicatorSeriesStore, selected: Int? = nil, range: Range<Int> = 0..<5) -> ChartContext {
        let ctx = ChartContext(seriesStore: store, items: items,
            appearance: ChartAppearance(indicatorStyleRegistry: [key: KDJStyle(kColor: .cyan, dColor: .orange, jColor: .purple)]),
            candleDimensions: dimensions, visibleRange: range, layout: layout, location: nil, selectedIndex: selected)
        ctx.viewPort = layer.bounds
        ctx.legendFrame = CGRect(x: 0, y: 0, width: 190, height: 20)
        ctx.legendText = renderer.legend(context: ctx)
        return ctx
    }
    let ctx = context(store)
    #expect(renderer.dataBounds(context: ctx).min == -20)
    #expect(renderer.dataBounds(context: ctx).max == 150)
    renderer.draw(in: layer, context: ctx)
    let shapeLayers = (layer.sublayers ?? []).compactMap { $0 as? CAShapeLayer }
    #expect(shapeLayers.count == 5)
    let kPath = shapeLayers[2].path!
    var moves = 0, segments = 0
    kPath.applyWithBlock { pointer in
        if pointer.pointee.type == .moveToPoint { moves += 1 }
        if pointer.pointee.type == .addLineToPoint { segments += 1 }
    }
    #expect(moves == 2 && segments == 2)
    #expect(shapeLayers[2].strokeColor == UIColor.cyan.cgColor)
    let before = (layer.sublayers?.last as? CATextLayer)?.string as? NSAttributedString
    let selected = context(store, selected: 0)
    renderer.updateLegend(context: selected)
    let after = (layer.sublayers?.last as? CATextLayer)?.string as? NSAttributedString
    #expect(before?.string != after?.string)
    #expect(after?.string.contains("KDJ(2,3,3)") == true)

    let slice = context(store, range: 3..<5)
    #expect(renderer.dataBounds(context: slice).min == 0)
    renderer.draw(in: layer, context: slice)
    #expect((layer.sublayers ?? []).map(ObjectIdentifier.init) == identities)
    renderer.draw(in: layer, context: context(IndicatorSeriesStore()))
    #expect(shapeLayers.allSatisfy { $0.path == nil })
    #expect((layer.sublayers?.last as? CATextLayer)?.string == nil)
    renderer.uninstall(from: layer)
    #expect(layer.sublayers?.isEmpty != false)
}

@Test @MainActor func subRendererHandlesPartialADXAndNonFiniteScalarValues() {
    let dmiKey = SeriesKey.dmi(diPeriod: 2, adxPeriod: 2)
    let wrKey = SeriesKey.wr(period: 2)
    var store = IndicatorSeriesStore()
    store.setValues(ContiguousArray<DMIIndicatorValue?>([
        .init(plusDI: 10, minusDI: 20, adx: nil), .init(plusDI: 20, minusDI: 10, adx: nil)
    ]), for: dmiKey)
    store.setValues(ContiguousArray<Double?>([.nan, .infinity]), for: wrKey)
    let scroll = ChartScrollView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    let dimensions = CandleDimensions(width: 8, gap: 2)
    let layout = ChartLayout(scrollView: scroll, candleDimensions: dimensions)
    layout.itemCount = 2
    layout.dataBounds = ValueBounds(min: 0, max: 100)
    let ctx = ChartContext(seriesStore: store, items: [testCandle(0, 1), testCandle(60, 2)],
        appearance: ChartAppearance(), candleDimensions: dimensions, visibleRange: 0..<2,
        layout: layout, location: nil, selectedIndex: nil)
    ctx.viewPort = scroll.bounds
    let dmi = SubIndicatorRenderer.make(key: dmiKey)
    let dmiLayer = CALayer()
    dmi.install(to: dmiLayer)
    dmi.draw(in: dmiLayer, context: ctx)
    let shapes = (dmiLayer.sublayers ?? []).compactMap { $0 as? CAShapeLayer }
    #expect(shapes[2].path?.isEmpty == false && shapes[3].path?.isEmpty == false)
    #expect(shapes[4].path?.isEmpty == true)
    #expect(dmi.legend(context: ctx)?.string.contains("ADX:") == false)
    let wr = SubIndicatorRenderer.make(key: wrKey)
    let wrLayer = CALayer()
    wr.install(to: wrLayer)
    wr.draw(in: wrLayer, context: ctx)
    #expect(wr.dataBounds(context: ctx).min == -100)
    #expect(wr.dataBounds(context: ctx).max == 0)
    #expect(wr.legend(context: ctx) == nil)
    #expect((wrLayer.sublayers?[2] as? CAShapeLayer)?.path?.isEmpty == true)
}

@Test @MainActor func additionalIndicatorPluginsRespectCompleteKeysAndThemeStyles() {
    let k1 = SeriesKey.kdj(period: 9, kPeriod: 3, dPeriod: 3)
    let k2 = SeriesKey.kdj(period: 5, kPeriod: 2, dPeriod: 4)
    let parameters = IndicatorConfiguration(seriesKeys: [.kdj: [k1, k2]])
    let plugin = BuiltInIndicatorPlugin(indicator: .kdj, configuration: parameters)
    #expect(plugin.makeCalculators(configuration: parameters).map(\.id) == [k1, k2])
    #expect(plugin.makeRenderers(configuration: parameters).count == 2)
    let bad = SeriesKey(indicatorID: .kdj, name: "KDJ", parameters: ["period": "9", "kPeriod": "invalid", "dPeriod": "3"])
    let malformed = IndicatorConfiguration(seriesKeys: [.kdj: [bad]])
    #expect(plugin.makeCalculators(configuration: malformed).isEmpty)
    #expect(plugin.makeRenderers(configuration: malformed).isEmpty)
    #expect(BuiltInIndicator.allCases.map(\.id) == IndicatorID.allBuiltIn)
    for theme in [ChartAppearance(), .themed(.midnight), .themed(.solaris)] {
        #expect(theme.indicatorStyle(for: k1, type: KDJStyle.self) != nil)
        #expect(theme.indicatorStyle(for: .dmi(diPeriod: 14, adxPeriod: 14), type: DMIStyle.self) != nil)
        for indicator in additionalIndicators where indicator != .kdj && indicator != .dmi {
            #expect(theme.indicatorStyle(for: indicator.defaultSeriesKeys[0], type: LineStyle.self) != nil)
        }
    }
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1)), arguments: [CGFloat(390), CGFloat(1024)]) @MainActor
func nineAdditionalIndicatorsPublishAndDrawIndependentPanels(width: CGFloat) async throws {
    let items: [any ChartItem] = (0..<120).map {
        testCandle($0 * 60, 100 + sin(Double($0) * 0.3) * 12)
    }
    let selected = IndicatorSelection(subIndicatorIDs: additionalIndicators.map(\.id))
    let customKDJ = SeriesKey.kdj(period: 5, kPeriod: 2, dPeriod: 4)
    let customDMI = SeriesKey.dmi(diPeriod: 5, adxPeriod: 3)
    let parameters = IndicatorConfiguration(seriesKeys: [
        .kdj: BuiltInIndicator.kdj.defaultSeriesKeys + [customKDJ],
        .dmi: BuiltInIndicator.dmi.defaultSeriesKeys + [customDMI],
        .wr: [.wr(period: 14), .wr(period: 7)]
    ])
    let chart = ChartView(configuration: try testConfiguration(items: items,
        indicatorConfiguration: parameters), indicators: selected)
    defer { chart.shutdown() }
    #expect(await eventually { chart.debugItemTimestamps.count == 120 })
    await chart.debugWaitForRefresh()
    for indicator in additionalIndicators {
        #expect(chart.debugVisiblePluginIDs.contains(indicator.id.rawValue))
        let store = chart.debugStore(for: indicator.id.rawValue)
        if indicator == .kdj {
            #expect(store.values(for: indicator.defaultSeriesKeys[0], as: KDJIndicatorValue.self)?[119] != nil)
            #expect(store.values(for: customKDJ, as: KDJIndicatorValue.self)?[119] != nil)
        } else if indicator == .dmi {
            #expect(store.values(for: indicator.defaultSeriesKeys[0], as: DMIIndicatorValue.self)?[119]?.adx != nil)
            #expect(store.values(for: customDMI, as: DMIIndicatorValue.self)?[119]?.adx != nil)
        } else {
            #expect(store.values(for: indicator.defaultSeriesKeys[0], as: Double.self)?[119] != nil)
        }
    }
    #expect(chart.debugStore(for: "builtin.wr").values(for: .wr(period: 7), as: Double.self)?[119] != nil)
    chart.frame = CGRect(x: 0, y: 0, width: width, height: chart.intrinsicContentSize.height)
    chart.backgroundColor = .white
    chart.overrideUserInterfaceStyle = .light
    chart.scrollToLatest()
    let image = chart.debugRenderForInspection()
    let paths = allLayers(chart.layer).compactMap { ($0 as? CAShapeLayer)?.path }.filter { !$0.isEmpty }
    #expect(paths.count >= 25)
    #expect(paths.allSatisfy { !$0.boundingBoxOfPath.isInfinite && !$0.boundingBoxOfPath.isNull })
    #expect(!chart.hasAmbiguousLayout)
    let legends = allLayers(chart.layer).compactMap { $0 as? CATextLayer }
    let texts = legends.compactMap { ($0.string as? NSAttributedString)?.string }
    for indicator in additionalIndicators { #expect(texts.contains { $0.contains(indicator.rawValue) }) }
    #expect(legends.filter { ($0.string as? NSAttributedString)?.string.contains("KDJ(") == true }.count == 1)
    #expect(chart.intrinsicContentSize.height >= CGFloat(9) * ChartAppearance().layoutMetrics.indicatorHeight)
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let folder = root.appendingPathComponent(".build/validation")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try #require(image.pngData()).write(to: folder.appendingPathComponent("sub-indicators-\(Int(width)).png"))

    chart.debugInspectCandle(at: 95)
    #expect(chart.debugSelectedCandleIndex == 95)
    var withoutKDJ = chart.indicators
    withoutKDJ.subIndicatorIDs.removeAll { $0 == .kdj }
    chart.setIndicators(withoutKDJ)
    await chart.debugWaitForRefresh()
    #expect(!chart.debugVisiblePluginIDs.contains("builtin.kdj"))
    #expect(chart.debugStore(for: "builtin.kdj").values(for: customKDJ, as: KDJIndicatorValue.self) == nil)
    chart.setIndicators(selected)
    await chart.debugWaitForRefresh()
    #expect(chart.debugStore(for: "builtin.kdj").values(for: customKDJ, as: KDJIndicatorValue.self)?[119] != nil)

    let retained = try #require(chart.debugRenderer(for: "builtin.kdj", as: SubIndicatorRenderer.self))
    chart.apply(try testConfiguration(items: items, indicatorConfiguration: IndicatorConfiguration(seriesKeys: [
        .kdj: BuiltInIndicator.kdj.defaultSeriesKeys + [customKDJ],
        .dmi: BuiltInIndicator.dmi.defaultSeriesKeys + [customDMI],
        .wr: [.wr(period: 21)]
    ])))
    await chart.debugWaitForRefresh()
    #expect(chart.debugRenderer(for: "builtin.kdj", as: SubIndicatorRenderer.self) === retained)
    #expect(chart.debugStore(for: "builtin.wr").values(for: .wr(period: 14), as: Double.self) == nil)
    #expect(chart.debugStore(for: "builtin.wr").values(for: .wr(period: 21), as: Double.self)?[119] != nil)
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func newSubIndicatorSelectionRoundTripsAndReapplies() async throws {
    let selected = IndicatorSelection(subIndicatorIDs: additionalIndicators.map(\.id))
    let encoded = try JSONEncoder().encode(selected)
    #expect(try JSONDecoder().decode(IndicatorSelection.self, from: encoded) == selected)
    let items = (0..<100).map { testCandle($0 * 60, Double($0 + 1)) }
    let config = try testConfiguration(items: items)
    let chart = ChartView(configuration: config, indicators: selected)
    defer { chart.shutdown() }
    #expect(await eventually { chart.debugItemTimestamps.count == 100 })
    #expect(chart.indicators == selected)
    var withoutMFI = chart.indicators
    withoutMFI.subIndicatorIDs.removeAll { $0 == .mfi }
    chart.setIndicators(withoutMFI)
    await chart.debugWaitForRefresh()
    #expect(chart.indicators == withoutMFI)
    let restored = ChartView(configuration: try testConfiguration(items: items), indicators: withoutMFI)
    defer { restored.shutdown() }
    #expect(restored.indicators == withoutMFI)
}
#endif
