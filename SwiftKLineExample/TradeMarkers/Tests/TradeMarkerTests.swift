//
//  TradeMarkerTests.swift
//  SwiftKLineExampleTests
//
//  Created by zhwayne on 2026/10/21.
//

#if canImport(UIKit)
import UIKit
import Foundation
import Testing
import SwiftKLine
@testable import SwiftKLineUI

/// A synchronous test counter for CPU work performed by child tasks, not production async state.
private final class TestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func increment() { lock.withLock { value += 1 } }
    var count: Int { lock.withLock { value } }
}

private final class TestSnapshotProvider: ChartItemProvider, Sendable {
    let items: [any ChartItem]
    init(_ items: [any ChartItem]) { self.items = items }
    func fetchChartItems(forPage page: Int) async throws -> [any ChartItem] { page == 0 ? items : [] }
    func fetchChartItems(from start: Date, to end: Date) async throws -> [any ChartItem] { [] }
}

private func testCandle(_ timestamp: Int, _ close: Double) -> Candle {
    Candle(timestamp: timestamp, open: close, high: close + 2, low: close - 2, close: close, volume: 100)
}

/// Polls a semantic condition with a deadline, not a fixed timing assumption.
@MainActor
private func eventually(_ condition: () -> Bool) async -> Bool {
    for _ in 0..<2_000 {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
    return condition()
}

private actor Event {
    private var opened = false
    private var waiting: [CheckedContinuation<Void, Never>] = []
    func wait() async { if !opened { await withCheckedContinuation { waiting.append($0) } } }
    func open() { opened = true; let pending = waiting; waiting = []; pending.forEach { $0.resume() } }
}
private actor TradePages: RangeDataProvider {
    enum Failure: Error { case offline }
    let requested = Event(), release = Event()
    let markerID: String
    var shouldFail: Bool
    private(set) var requests = 0
    init(_ markerID: String = "trade", failOnce: Bool = false) { self.markerID = markerID; shouldFail = failOnce }
    func fetch(in range: Range<Date>, cursor: Int?) async throws -> RangePage<TradeMarker, Int> {
        requests += 1
        await requested.open()
        await release.wait()
        if shouldFail { shouldFail = false; throw Failure.offline }
        return RangePage(items: [TradeMarker(id: markerID, timestamp: Date(timeIntervalSince1970: 65), price: 10, side: .buy)], nextCursor: nil)
    }
}
private struct CountingCalculator: IndicatorCalculator {
    let id = SeriesKey(indicatorID: "count", name: "count")
    let counter: TestCounter
    func calculate(for items: [any ChartItem]) -> [Double?] { counter.increment(); return items.map { $0.close } }
}
@MainActor private struct CountingPlugin: ChartPlugin {
    let id = "calculation"
    let counter: TestCounter
    @MainActor final class Coordinator { var configured = false }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func update(coordinator: Coordinator, context: ChartPluginContext) {
        guard !coordinator.configured else { return }
        coordinator.configured = true
        context.setCalculator(CountingCalculator(counter: counter), for: "count")
    }
}
@MainActor private func configuration(_ provider: TradePages, sourceID: String = "account-one", retry: Int = 0,
                                     counter: TestCounter, factories: TestCounter,
                                     content: ChartType = .candlestick) throws -> ChartConfiguration {
    try ChartConfiguration(source: CandleSource(id: "candles", duration: 60) {
        factories.increment(); return TestSnapshotProvider([testCandle(60, 10), testCandle(120, 12)])
    }, content: content, plugins: [CountingPlugin(counter: counter),
        TradeMarkers(sourceID: sourceID, retryID: retry, provider: { provider })], features: [])
}
@MainActor private func show(_ chart: ChartView) {
    chart.frame = CGRect(x: 0, y: 0, width: 320, height: chart.intrinsicContentSize.height)
    _ = chart.debugRenderForInspection()
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func independentTradePagesDoNotBlockOrRecalculateCandles() async throws {
    for content in [ChartType.candlestick, .timeSeries] {
        let provider = TradePages(), calculations = TestCounter(), factories = TestCounter()
        let chart = ChartView(configuration: try configuration(provider, counter: calculations, factories: factories, content: content))
        #expect(await eventually { chart.debugItemTimestamps.count == 2 })
        show(chart)
        await provider.requested.wait()
        let baseline = calculations.count
        #expect(chart.debugRenderedCloses == [10, 12])
        #expect(chart.debugRenderer(for: "trades", as: TradeMarkerRenderer.self)?.items.isEmpty == true)
        await provider.release.open()
        #expect(await eventually { chart.debugRenderer(for: "trades", as: TradeMarkerRenderer.self)?.items.count == 1 })
        _ = chart.debugRenderForInspection()
        #expect(calculations.count == baseline)
        #expect(factories.count == 1)
        chart.shutdown()
    }
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func changingOnlyTheTradeAccountRejectsOldResults() async throws {
    let old = TradePages("old"), new = TradePages("new"), counter = TestCounter(), factories = TestCounter()
    let chart = ChartView(configuration: try configuration(old, counter: counter, factories: factories))
    #expect(await eventually { chart.debugItemTimestamps.count == 2 })
    show(chart)
    await old.requested.wait()
    chart.apply(try configuration(new, sourceID: "account-two", counter: counter, factories: factories))
    await new.release.open()
    #expect(await eventually { chart.debugRenderer(for: "trades", as: TradeMarkerRenderer.self)?.items.first?.id == "new" })
    await old.release.open()
    for _ in 0..<20 { await Task.yield() }
    #expect(chart.debugRenderer(for: "trades", as: TradeMarkerRenderer.self)?.items.map(\.id) == ["new"])
    #expect(factories.count == 1)
    chart.shutdown()
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func tradeRetryDoesNotRestartTheCandleProvider() async throws {
    let provider = TradePages(failOnce: true), counter = TestCounter(), factories = TestCounter()
    await provider.release.open()
    let chart = ChartView(configuration: try configuration(provider, counter: counter, factories: factories))
    let failed = Event()
    chart.onPluginError = { id, _ in if id == "trades" { Task { await failed.open() } } }
    #expect(await eventually { chart.debugItemTimestamps.count == 2 })
    show(chart)
    await failed.wait()
    let calls = counter.count
    chart.apply(try configuration(provider, retry: 1, counter: counter, factories: factories))
    #expect(await eventually { chart.debugRenderer(for: "trades", as: TradeMarkerRenderer.self)?.items.count == 1 })
    #expect(await provider.requests == 2)
    #expect(factories.count == 1)
    #expect(counter.count == calls)
    chart.shutdown()
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func applicationCompositionLoadsAllIndependentPages() async throws {
    let candles = [testCandle(60, 10), testCandle(120, 12)]
    let trades = (0..<201).map { index in
        TradeMarker(id: "execution-\(index)", timestamp: Date(timeIntervalSince1970: 65 + Double(index) / 100),
                    price: 10, side: index.isMultiple(of: 2) ? .buy : .sell)
    }
    let chart = ChartView(configuration: try tradeMarkerConfiguration(candles: candles, trades: trades))
    #expect(await eventually { chart.debugItemTimestamps.count == candles.count })
    show(chart)
    #expect(await eventually {
        chart.debugRenderer(for: "account.trades", as: TradeMarkerRenderer.self)?.items.count == trades.count
    })
    #expect(chart.debugRenderedCloses == [10, 12])
    chart.shutdown()
}

private actor MarketHistory: ChartItemProvider {
    let candles: [Candle]
    private(set) var requests: [(Date, Date)] = []
    init(candles: [Candle]) { self.candles = candles }
    func fetchChartItems(forPage page: Int) async throws -> [any ChartItem] { [] }
    func fetchChartItems(from start: Date, to end: Date) async throws -> [any ChartItem] {
        requests.append((start, end))
        // Match the exchange's inclusive interval so the demo must exclude page-end duplicates itself.
        return candles.filter {
            let date = Date(timeIntervalSince1970: Double($0.timestamp))
            return start <= date && date <= end
        }
    }
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1)), arguments: [ChartPeriod.oneMinute, .oneMonth])
func marketBackedDemoPagesPreserveBoundariesAndStableExecutions(period: ChartPeriod) async throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let base = Date(timeIntervalSince1970: 1_704_067_200)
    let opens = (0...30).map { index in
        period == .oneMonth ? calendar.date(byAdding: .month, value: index, to: base)!
            : base.addingTimeInterval(Double(index * period.seconds))
    }
    let candles = opens.enumerated().map { testCandle(Int($0.element.timeIntervalSince1970), 100 + Double($0.offset)) }
    let market = MarketHistory(candles: candles)
    let provider = DemoTradeProvider(provider: market, period: period)
    let range = opens[0]..<opens[30]
    var cursor: Date?
    var trades: [TradeMarker] = []
    for _ in 0..<10 {
        let page = try await provider.fetch(in: range, cursor: cursor)
        trades += page.items
        guard let next = page.nextCursor else { break }
        try #require(next > (cursor ?? range.lowerBound) && next < range.upperBound)
        cursor = next
    }
    #expect(trades.count == 6)
    #expect(Set(trades.map(\.id)).count == trades.count)
    #expect(trades.allSatisfy { range.contains($0.timestamp) })
    #expect(trades.filter { $0.side == .buy }.count == 3)
    let requests = await market.requests
    #expect(requests.first?.0 == range.lowerBound)
    #expect(requests.last?.1 == range.upperBound)
    for index in 1..<requests.count { #expect(requests[index - 1].1 == requests[index].0) }
    let overlap = try await provider.fetch(in: opens[5]..<opens[15], cursor: nil)
    #expect(!overlap.items.isEmpty)
    #expect(Set(overlap.items).isSubset(of: Set(trades)))
}

@Test @MainActor func markerLayersClipToThePriceViewport() throws {
    let scroll = ChartScrollView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    let dimensions = CandleDimensions(width: 8, gap: 2)
    let layout = ChartLayout(scrollView: scroll, candleDimensions: dimensions)
    layout.itemCount = 1
    layout.dataBounds = ValueBounds(min: 8, max: 14)
    let context = ChartContext(seriesStore: IndicatorSeriesStore(), items: [testCandle(60, 10)],
        appearance: ChartAppearance(), candleDimensions: dimensions, visibleRange: 0..<1,
        layout: layout, location: nil, selectedIndex: nil, candleInterval: { timestamp in
            let start = Date(timeIntervalSince1970: Double(timestamp)); return start..<start.addingTimeInterval(60)
        })
    context.viewPort = CGRect(x: 0, y: 10, width: 200, height: 50)
    let renderer = TradeMarkerRenderer(), canvas = CALayer()
    renderer.items = [TradeMarker(id: "outside", timestamp: Date(timeIntervalSince1970: 65), price: 10_000, side: .buy)]
    renderer.install(to: canvas)
    renderer.draw(in: canvas, context: context)
    let viewport = try #require(canvas.sublayers?.first)
    #expect(viewport.masksToBounds)
    #expect(viewport.frame == context.viewPort)
    #expect(renderer.dataBounds(context: context) == .empty)
}
#endif
