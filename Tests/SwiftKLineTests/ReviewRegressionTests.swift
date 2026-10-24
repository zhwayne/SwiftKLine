//
//  ReviewRegressionTests.swift
//  SwiftKLineTests
//
//  Created by zhwayne on 2026/10/24.
//

#if canImport(UIKit)
import Foundation
import UIKit
import Testing
import SwiftKLineCore
@testable import SwiftKLineUI

private final class ReviewLiveProvider: ChartItemProvider, Sendable {
    let subscriptions: TestCounter
    let pages: TestCounter
    init(_ subscriptions: TestCounter, pages: TestCounter = TestCounter()) {
        self.subscriptions = subscriptions
        self.pages = pages
    }
    func fetchChartItems(forPage page: Int) async throws -> [any ChartItem] {
        pages.increment()
        return page == 0 ? [testCandle(60, 1)] : []
    }
    func fetchChartItems(from: Date, to: Date) async throws -> [any ChartItem] { [] }
    func liveStream() -> AsyncStream<any ChartItem> {
        subscriptions.increment()
        return AsyncStream { _ in }
    }
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func inactiveReplacementDoesNotSubscribeUntilActivated() async throws {
    let first = TestCounter(), second = TestCounter()
    func config(_ id: String, _ counter: TestCounter) throws -> ChartConfiguration {
        try ChartConfiguration(source: CandleSource(id: id, duration: 60) { ReviewLiveProvider(counter) },
                               features: [.liveUpdates])
    }
    let initial = try config("initial", first)
    let coordinator = ChartCoordinator(configuration: initial)
    defer { coordinator.shutdown() }
    coordinator.setActive(false)
    coordinator.apply(initial, initial: true)
    #expect(await eventually { coordinator.snapshot.items.count == 1 })
    #expect(first.count == 0)
    coordinator.setActive(true)
    #expect(await eventually { first.count >= 1 })
    coordinator.setActive(false)
    coordinator.apply(try config("replacement", second))
    #expect(await eventually { coordinator.snapshot.items.count == 1 })
    #expect(second.count == 0)
    coordinator.setActive(true)
    #expect(await eventually { second.count >= 1 })
}

private final class MutableReviewStyle: IndicatorStyle, Equatable {
    var value = 0
    static func == (lhs: MutableReviewStyle, rhs: MutableReviewStyle) -> Bool { lhs.value == rhs.value }
}

private struct WrappedReviewStyle: IndicatorStyle, Equatable { let reference: MutableReviewStyle }

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1)), arguments: [false, true])
@MainActor func sharedMutableEquatableStyleStillInvalidatesDrawing(wrapped: Bool) async throws {
    let style = MutableReviewStyle()
    let declared: any IndicatorStyle = wrapped ? WrappedReviewStyle(reference: style) : style
    let config = try testConfiguration(appearance: ChartAppearance(indicatorStyleRegistry: [.ma(period: 5): declared]))
    let coordinator = ChartCoordinator(configuration: config)
    defer { coordinator.shutdown() }
    coordinator.apply(config, initial: true)
    #expect(await eventually { coordinator.snapshot.items.count == 2 })
    await coordinator.waitForRefresh()
    var redraws = 0
    coordinator.onResources = { _ in redraws += 1 }
    style.value = 1
    coordinator.apply(config)
    #expect(redraws == 1)
}

@MainActor private final class ClosingReviewState {
    var dismantles = 0
    var close: (() -> Void)?
}
@MainActor private struct ClosingReviewPlugin: ChartPlugin {
    let id = "closing"
    let state: ClosingReviewState
    func makeCoordinator() -> ClosingReviewState { state }
    func update(coordinator: ClosingReviewState, context: ChartPluginContext) {}
    static func dismantleCoordinator(_ coordinator: ClosingReviewState) {
        coordinator.dismantles += 1
        coordinator.close?()
    }
}

@MainActor private struct ReplacementReviewPlugin: ChartPlugin {
    let id = "closing"
    let creations: TestCounter
    func makeCoordinator() { creations.increment() }
    func update(coordinator: Void, context: ChartPluginContext) {}
}

@Test(arguments: [false, true])
@MainActor func pluginClosingHostDuringReplacementIsDismantledOnce(replaceSource: Bool) throws {
    let state = ClosingReviewState()
    let config = try testConfiguration(plugins: [ClosingReviewPlugin(state: state)])
    let coordinator = ChartCoordinator(configuration: config)
    coordinator.apply(config, initial: true)
    state.close = { coordinator.shutdown() }
    let creations = TestCounter()
    let replacement = try testConfiguration(id: replaceSource ? "replacement" : "test",
        plugins: [ReplacementReviewPlugin(creations: creations)])
    coordinator.apply(replacement)
    #expect(creations.count == 0)
    #expect(state.dismantles == 1)
    #expect(coordinator.isShutdown)
    #expect(coordinator.plugins.contexts.isEmpty)
    state.close = nil
    coordinator.shutdown()
}

@MainActor private final class LongReviewLegend: ChartRenderer {
    let id = "long-review-legend"
    func install(to layer: CALayer) {}
    func uninstall(from layer: CALayer) {}
    func draw(in layer: CALayer, context: ChartContext) {}
    func legend(context: ChartContext) -> NSAttributedString? {
        NSAttributedString(string: "DIF:0.00001234 DEA:0.00002345 MACD:0.00003456 PERIOD:12,26,9",
                           attributes: [.font: UIFont.systemFont(ofSize: 12)])
    }
}

@Test @MainActor func legendRemeasuresWhenAvailableSizeChanges() {
    let scroll = ChartScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 200))
    let dims = CandleDimensions()
    let layout = ChartLayout(scrollView: scroll, candleDimensions: dims)
    let context = ChartContext(seriesStore: IndicatorSeriesStore(), items: [], appearance: ChartAppearance(),
        candleDimensions: dims, visibleRange: 0..<0, layout: layout, location: nil, selectedIndex: nil)
    let group = RendererGroup(chartSection: .subChart, height: 200) { LongReviewLegend() }
    let coordinator = LegendCoordinator()
    let label = UILabel()
    var cache = LegendCache<Int>()
    let wideFrame = CGRect(x: 0, y: 0, width: 390, height: 200)
    let narrowFrame = CGRect(x: 0, y: 0, width: 180, height: 200)
    let wide = coordinator.configureLegend(for: group, groupFrame: wideFrame,
        legendKey: 1, legendLabel: label, legendCache: &cache, context: context)
    let narrow = coordinator.configureLegend(for: group, groupFrame: narrowFrame,
        legendKey: 1, legendLabel: label, legendCache: &cache, context: context)
    var freshCache = LegendCache<Int>()
    let fresh = coordinator.configureLegend(for: group, groupFrame: narrowFrame,
        legendKey: 1, legendLabel: label, legendCache: &freshCache, context: context)
    #expect(narrow.viewPortOffsetY == fresh.viewPortOffsetY)
    #expect(narrow.viewPortOffsetY > wide.viewPortOffsetY)
}

@MainActor private final class ReviewPinchGesture: UIPinchGestureRecognizer {
    private var simulatedState: UIGestureRecognizer.State = .possible
    override var state: UIGestureRecognizer.State {
        get { simulatedState }
        set { simulatedState = newValue }
    }
    override var numberOfTouches: Int { 2 }
    override func location(ofTouch touchIndex: Int, in view: UIView?) -> CGPoint {
        CGPoint(x: touchIndex == 0 ? 100 : 200, y: 70)
    }
}

@MainActor private func reviewPinch(_ scales: [CGFloat], count: Int = 100) -> (width: CGFloat, anchor: CGFloat) {
    let scroll = ChartScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 200))
    let layout = ChartLayout(scrollView: scroll, candleDimensions: CandleDimensions(width: 10, gap: 2))
    layout.itemCount = count
    scroll.contentInset = UIEdgeInsets(top: 0, left: 195, bottom: 0, right: 195)
    scroll.contentOffset = .zero
    let host = UIView(frame: scroll.bounds)
    let interaction = PinchInteraction(layout: layout) { change in
        layout.candleDimensions = CandleDimensions(width: change.width, gap: change.gap)
    }
    host.addInteraction(interaction)
    defer { host.removeInteraction(interaction) }
    let gesture = ReviewPinchGesture()
    gesture.state = .began
    gesture.scale = 1
    interaction.perform(NSSelectorFromString("handlePinch:"), with: gesture)
    for scale in scales {
        gesture.state = .changed
        gesture.scale = scale
        interaction.perform(NSSelectorFromString("handlePinch:"), with: gesture)
    }
    gesture.state = .ended
    interaction.perform(NSSelectorFromString("handlePinch:"), with: gesture)
    return (layout.candleDimensions.width, (scroll.contentOffset.x + 150) / layout.candleDimensions.itemWidth)
}

@Test @MainActor func pinchScaleIsIndependentOfEventSubdivisionAndReversible() {
    #expect(abs(reviewPinch([1.2]).width - reviewPinch([1.1, 1.2]).width) < 1e-10)
    #expect(abs(reviewPinch([1.2, 1]).width - 10) < 1e-10)
}

@Test @MainActor func crosshairDoesNotRoundSmallPricesToZero() throws {
    let view = CanvasView(frame: CGRect(x: 0, y: 0, width: 300, height: 120))
    let scroll = ChartScrollView(frame: view.bounds)
    let dims = CandleDimensions(width: 10, gap: 2)
    let layout = ChartLayout(scrollView: scroll, candleDimensions: dims)
    layout.itemCount = 1
    layout.dataBounds = ValueBounds(min: 0, max: 0.00002)
    var main = RendererGroup(chartSection: .mainChart, height: 100)
    main.groupFrame = CGRect(x: 0, y: 0, width: 300, height: 100)
    main.viewPort = main.groupFrame
    var timeline = RendererGroup(chartSection: .timeline, height: 20)
    timeline.groupFrame = CGRect(x: 0, y: 100, width: 300, height: 20)
    let context = ChartContext(seriesStore: IndicatorSeriesStore(), items: [testCandle(60, 0.00001234)],
        appearance: ChartAppearance(), candleDimensions: dims, visibleRange: 0..<1,
        layout: layout, location: CGPoint(x: 5, y: 38.3), selectedIndex: 0)
    context.groupFrame = main.groupFrame
    let renderer = CrosshairRenderer(configuration: context.appearance)
    renderer.candleGroup = main
    renderer.selectedGroup = main
    renderer.timelineGroup = timeline
    renderer.install(to: view.canvas)
    defer { renderer.uninstall(from: view.canvas) }
    renderer.draw(in: view.canvas, context: context)
    let texts = view.subviews.compactMap { ($0 as? UILabel)?.text }
    #expect(texts.contains("0.00001234"))
    #expect(!texts.contains("0.00"))
}
@Test @MainActor func pinchClampsWithoutLosingItsInitialScaleOrLogicalAnchor() {
    #expect(reviewPinch([10]).width == 24)
    #expect(abs(reviewPinch([10, 1]).width - 10) < 1e-10)
    #expect(reviewPinch([0.001]).width == 2)
    #expect(abs(reviewPinch([0.001, 1]).width - 10) < 1e-10)
    #expect(abs(reviewPinch([1.2], count: 20).anchor - 12.5) < 1e-10)
}

@Test(arguments: [false, true])
@MainActor func interactionsOwnOnlyTheirRecognizersAcrossMoveAndRemoval(crosshair: Bool) {
    let scroll = ChartScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 200))
    let layout = ChartLayout(scrollView: scroll, candleDimensions: CandleDimensions())
    let first = UIView(frame: scroll.bounds), second = UIView(frame: scroll.bounds)
    let foreign = UITapGestureRecognizer()
    first.addGestureRecognizer(foreign)
    let interaction: any UIInteraction = crosshair
        ? CrosshairInteraction(layout: layout) { _, _ in }
        : PinchInteraction(layout: layout) { _ in }
    let count = crosshair ? 2 : 1
    first.addInteraction(interaction)
    #expect(interaction.view === first)
    #expect(first.gestureRecognizers?.count == count + 1)
    first.removeInteraction(interaction)
    #expect(interaction.view == nil)
    #expect(first.gestureRecognizers?.count == 1)
    first.addInteraction(interaction)
    second.addInteraction(interaction)
    #expect(interaction.view === second)
    #expect(first.gestureRecognizers?.count == 1)
    #expect(second.gestureRecognizers?.count == count)
    second.removeInteraction(interaction)
    #expect(second.gestureRecognizers?.isEmpty != false)
    #expect(first.gestureRecognizers?.first === foreign)
}

@Test @MainActor func cancelledOrRemovedPinchRestoresThePreviousScrollState() {
    let scroll = ChartScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 200))
    let layout = ChartLayout(scrollView: scroll, candleDimensions: CandleDimensions())
    let host = UIView(frame: scroll.bounds)
    let interaction = PinchInteraction(layout: layout) { _ in }
    host.addInteraction(interaction)
    let gesture = ReviewPinchGesture()
    scroll.isScrollEnabled = false
    gesture.state = .began
    interaction.perform(NSSelectorFromString("handlePinch:"), with: gesture)
    gesture.state = .cancelled
    interaction.perform(NSSelectorFromString("handlePinch:"), with: gesture)
    #expect(!scroll.isScrollEnabled)
    scroll.isScrollEnabled = true
    gesture.state = .began
    interaction.perform(NSSelectorFromString("handlePinch:"), with: gesture)
    #expect(!scroll.isScrollEnabled)
    host.removeInteraction(interaction)
    #expect(scroll.isScrollEnabled)
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func activityCommandsBeforeStartAndOutOfOrderKeepTheLatestState() async {
    let subscriptions = TestCounter(), pages = TestCounter()
    let loader = ChartItemLoader(provider: ReviewLiveProvider(subscriptions, pages: pages),
        enablesGapRecovery: false, initiallyActive: false, eventHandler: { _ in })
    await loader.setActive(false, latestTimestamp: nil, revision: 4)
    await loader.setActive(true, latestTimestamp: nil, revision: 3)
    await loader.start()
    #expect(await eventually { pages.count == 1 })
    #expect(subscriptions.count == 0)
    await loader.recoverIfActive(latestTimestamp: nil)
    #expect(subscriptions.count == 0)
    await loader.setActive(true, latestTimestamp: nil, revision: 5)
    #expect(await eventually { subscriptions.count == 1 })
    await loader.stop()
    let beforeStart = TestCounter()
    let foreground = ChartItemLoader(provider: ReviewLiveProvider(beforeStart),
        enablesGapRecovery: false, initiallyActive: false, eventHandler: { _ in })
    await foreground.setActive(true, latestTimestamp: nil, revision: 1)
    await foreground.start()
    #expect(await eventually { beforeStart.count == 1 })
    await foreground.stop()
}

@Test @MainActor func degenerateLayoutMathFailsClosedWithoutIntegerTraps() {
    for width in [CGFloat.nan, .infinity, -1, 0, .leastNonzeroMagnitude] {
        let scroll = ChartScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 200))
        let layout = ChartLayout(scrollView: scroll, candleDimensions: CandleDimensions(width: width, gap: 0))
        layout.itemCount = 10
        #expect(layout.contentSize.width.isFinite)
        #expect(layout.visibleRange.isEmpty)
        #expect(layout.indexInViewport(on: 5) == nil)
    }
    let scroll = ChartScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 200))
    let layout = ChartLayout(scrollView: scroll, candleDimensions: CandleDimensions())
    layout.itemCount = 10
    #expect(layout.indexInViewport(on: .nan) == nil)
    #expect(layout.indexInViewport(on: .infinity) == nil)
    #expect(layout.indexInViewport(on: .greatestFiniteMagnitude) == nil)
}
#endif
