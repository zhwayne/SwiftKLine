//
//  DataLifecycleRegressionTests.swift
//  SwiftKLineTests
//
//  Created by zhwayne on 2026/10/21.
//

#if canImport(UIKit)
import Foundation
import Testing
@testable import SwiftKLineUI
@testable import SwiftKLineCore

private struct RegressionItem: ChartItem {
    let timestamp: Int
    let close: Double
    var open: Double { close }
    var high: Double { close + 1 }
    var low: Double { close - 1 }
    var volume: Double { 0 }
    var value: Double { 0 }
}

/// A one-shot async signal that controls request order without network access or fixed delays.
private actor Signal {
    private var signaled = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if signaled { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func signal() {
        signaled = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}

/// A deterministic provider whose page completion, live ticks, and termination are controlled by test signals.
private final class ControlledProvider: ChartItemProvider, Sendable {
    let releasePage = Signal()
    let pageRequested = Signal()
    private let initialItems: [any ChartItem]
    let streamRequested = Signal()
    let terminated = Signal()
    let stream: AsyncStream<any ChartItem>
    let continuation: AsyncStream<any ChartItem>.Continuation

    init(initialItems: [any ChartItem] = [RegressionItem(timestamp: 60, close: 1), RegressionItem(timestamp: 120, close: 2)]) {
        self.initialItems = initialItems
        (stream, continuation) = AsyncStream.makeStream()
        continuation.onTermination = { [terminated] _ in
            Task { await terminated.signal() }
        }
    }

    func fetchChartItems(forPage page: Int) async throws -> [any ChartItem] {
        guard page == 0 else { return [] }
        await pageRequested.signal()
        await releasePage.wait()
        return initialItems
    }

    func fetchChartItems(from start: Date, to end: Date) async throws -> [any ChartItem] { [] }

    func liveStream() -> AsyncStream<any ChartItem> {
        Task { await streamRequested.signal() }
        return stream
    }
}


@MainActor private func configuration(_ provider: ControlledProvider, id: String = "live",
                                      plugins: [any ChartPlugin] = []) -> ChartConfiguration {
    try! ChartConfiguration(source: CandleSource(id: id, duration: 60, provider: { provider }),
                            plugins: plugins, features: [.liveUpdates])
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func initialPagePreservesNewAndUpdatedLiveCandles() async {
    let provider = ControlledProvider()
    let config = configuration(provider)
    let coordinator = ChartCoordinator(configuration: config)
    let ticks = Signal(), page = Signal()
    coordinator.onSnapshot = { _ in
        if coordinator.snapshot.items.map(\.timestamp) == [120, 180] { Task { await ticks.signal() } }
        if coordinator.snapshot.items.map(\.timestamp) == [60, 120, 180] { Task { await page.signal() } }
    }
    coordinator.apply(config, initial: true)
    await provider.streamRequested.wait()
    provider.continuation.yield(RegressionItem(timestamp: 120, close: 20))
    provider.continuation.yield(RegressionItem(timestamp: 120, close: 22))
    provider.continuation.yield(RegressionItem(timestamp: 180, close: 3))
    await ticks.wait()
    await provider.releasePage.signal()
    await page.wait()
    #expect(coordinator.snapshot.items.map(\.close) == [1, 22, 3])
    coordinator.shutdown()
    await provider.terminated.wait()
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) func releasingLoaderCancelsInfiniteStream() async {
    let provider = ControlledProvider()
    await provider.releasePage.signal()
    var loader: ChartItemLoader? = ChartItemLoader(provider: provider, eventHandler: { _ in })
    weak var reference: ChartItemLoader?
    reference = loader
    await loader?.start()
    await provider.streamRequested.wait()
    loader = nil
    await provider.terminated.wait()
    #expect(reference == nil)
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func stoppingCoordinatorTerminatesLiveSubscription() async {
    let provider = ControlledProvider()
    await provider.releasePage.signal()
    let config = configuration(provider)
    let coordinator = ChartCoordinator(configuration: config)
    coordinator.apply(config, initial: true)
    await provider.streamRequested.wait()
    coordinator.shutdown()
    await provider.terminated.wait()
}

// Synchronous calculators need a synchronous test gate; the lock does not protect production async state.
/// A lock-backed test gate that blocks a synchronous calculator until the test explicitly releases it.
private final class CalculationGate: @unchecked Sendable {
    private let condition = NSCondition()
    private var released = false
    let started: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() { (started, continuation) = AsyncStream.makeStream() }

    func block() {
        condition.lock()
        continuation.yield(())
        while !released { condition.wait() }
        condition.unlock()
    }

    func release() {
        condition.lock()
        released = true
        condition.broadcast()
        condition.unlock()
    }
}

/// A test calculator that deliberately delays one input snapshot to exercise cancellation and publication ordering.
private struct GatedCalculator: IndicatorCalculator {
    let id = SeriesKey(indicatorID: "test.gated", name: "gated")
    let gate: CalculationGate
    let factor: Double
    func calculate(for items: [any ChartItem]) -> [Double?] {
        if items.first?.timestamp == 999 { gate.block() }
        return items.map { $0.close * factor }
    }
}


@MainActor private struct GatedPlugin: ChartPlugin {
    let id = "test.gated"
    let gate: CalculationGate
    var factor: Double = 1
    @MainActor final class Coordinator { var factor: Double? }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func update(coordinator: Coordinator, context: ChartPluginContext) {
        guard coordinator.factor != factor else { return }
        coordinator.factor = factor
        context.setCalculator(GatedCalculator(gate: gate, factor: factor), for: "gated")
    }
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func oldDrawCannotRestoreItemsAfterProviderReplacement() async {
    let gate = CalculationGate()
    defer { gate.release() }
    let view = ChartView(configuration: try! testConfiguration(id: "old", items: [testCandle(999, 99)],
        plugins: [GatedPlugin(gate: gate)]))
    for await _ in gate.started { break }
    let provider = ControlledProvider()
    view.apply(configuration(provider, id: "new", plugins: [GatedPlugin(gate: gate)]))
    gate.release()
    await view.debugWaitForRefresh()
    #expect(view.debugCoordinatorItemTimestamps.isEmpty)
    #expect(view.debugItemTimestamps.isEmpty)
    await provider.releasePage.signal()
    view.shutdown()
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func oldCalculationCannotOverwriteNewIndicatorValues() async {
    let gate = CalculationGate()
    defer { gate.release() }
    let view = ChartView(configuration: try! testConfiguration(items: [testCandle(999, 99)],
        plugins: [GatedPlugin(gate: gate)]))
    for await _ in gate.started { break }
    view.apply(try! testConfiguration(items: [testCandle(999, 99)], plugins: [GatedPlugin(gate: gate, factor: 2)]))
    gate.release()
    await view.debugWaitForRefresh()
    #expect(view.debugItemTimestamps == [999])
    #expect(view.debugStore(for: "test.gated").values(for: SeriesKey(indicatorID: "test.gated", name: "gated"), as: Double.self) == [198])
}

@Test(arguments: [(0, 26, 9), (12, 0, 1), (12, 26, 0), (-1, 26, 9), (12, -1, 9), (12, 26, -1), (12, 26, Int.max)])
func macdRejectsInvalidPeriods(periods: (Int, Int, Int)) {
    let items = (0..<40).map { RegressionItem(timestamp: $0, close: Double($0)) }
    let values = MACDCalculator(shortPeriod: periods.0, longPeriod: periods.1, signalPeriod: periods.2).calculate(for: items)
    #expect(values.count == items.count)
    #expect(values.allSatisfy { $0 == nil })
}

@Test func macdValidPeriodsStillProduceValues() {
    let items = (0..<40).map { RegressionItem(timestamp: $0, close: Double($0)) }
    let values = MACDCalculator().calculate(for: items)
    #expect(values[32] == nil)
    #expect(values[33]?.histogram.isFinite == true)
    #expect(values[39]?.signal.isFinite == true)
}

@Test(arguments: [false, true])
func sarUsesReversalExtremeOnReversalCandle(mirrored: Bool) {
    // Mirror the prices to cover both rising-to-falling and falling-to-rising reversals.
    let closes: [Double] = mirrored ? [10, 8, 14] : [10, 12, 6]
    let items = closes.enumerated().map { RegressionItem(timestamp: $0.offset, close: $0.element) }
    let values = SARCalculator().calculate(for: items)
    #expect(values[2] == (mirrored ? 7 : 13))
}


@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func ticksDuringSlowCalculationAreEventuallyPublished() async {
    let gate = CalculationGate()
    defer { gate.release() }
    let provider = ControlledProvider(initialItems: [RegressionItem(timestamp: 999, close: 1)])
    await provider.releasePage.signal()
    let view = ChartView(configuration: configuration(provider, plugins: [GatedPlugin(gate: gate)]))
    for await _ in gate.started { break }
    provider.continuation.yield(RegressionItem(timestamp: 999, close: 7))
    provider.continuation.yield(RegressionItem(timestamp: 1000, close: 8))
    #expect(await eventually { view.debugCoordinatorItemTimestamps == [999, 1000] })
    gate.release()
    await view.debugWaitForRefresh()
    #expect(view.debugRenderedCloses == [7, 8])
    #expect(view.debugStore(for: "test.gated").values(for: SeriesKey(indicatorID: "test.gated", name: "gated"), as: Double.self) == [7, 8])
    view.shutdown()
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func emptyInitialPageStillReplaysLiveTicks() async {
    let provider = ControlledProvider(initialItems: [])
    let config = configuration(provider)
    let coordinator = ChartCoordinator(configuration: config)
    let tick = Signal(), page = Signal()
    coordinator.onSnapshot = { _ in
        if !coordinator.snapshot.items.isEmpty { Task { await tick.signal() } }
    }
    coordinator.apply(config, initial: true)
    await provider.streamRequested.wait()
    provider.continuation.yield(RegressionItem(timestamp: 60, close: 7))
    await tick.wait()
    coordinator.onSnapshot = { _ in Task { await page.signal() } }
    await provider.releasePage.signal()
    await page.wait()
    #expect(coordinator.snapshot.items.map(\.close) == [7])
    coordinator.shutdown()
    await provider.terminated.wait()
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) func releasingLoaderDoesNotWaitForUncooperativePageRequest() async {
    let provider = ControlledProvider()
    var loader: ChartItemLoader? = ChartItemLoader(provider: provider, enablesLiveUpdates: false, eventHandler: { _ in })
    await loader?.start()
    await provider.pageRequested.wait()
    weak var reference: ChartItemLoader?
    reference = loader
    loader = nil
    #expect(reference == nil)
    await provider.releasePage.signal()
}
private final class TwoPageProvider: ChartItemProvider, Sendable {
    func fetchChartItems(forPage page: Int) async throws -> [any ChartItem] {
        switch page {
        case 0: return [RegressionItem(timestamp: 999, close: 2)]
        case 1: return [RegressionItem(timestamp: 60, close: 1)]
        default: return []
        }
    }
    func fetchChartItems(from start: Date, to end: Date) async throws -> [any ChartItem] { [] }
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func historyQueuedDuringCalculationBypassesLiveThrottling() async throws {
    let gate = CalculationGate()
    defer { gate.release() }
    let config = try ChartConfiguration(source: CandleSource(id: "history", duration: 60) { TwoPageProvider() },
        plugins: [GatedPlugin(gate: gate)], features: [])
    // A deliberately long live delay makes the priority contract observable without a tight timing threshold.
    let coordinator = ChartCoordinator(configuration: config, liveUpdateDelay: 10_000_000_000)
    defer { coordinator.shutdown() }
    coordinator.apply(config, initial: true)
    for await _ in gate.started { break }
    coordinator.loadMore(contentOffsetX: 0, viewportWidth: 390)
    #expect(await eventually { coordinator.rawItems.count == 2 })
    gate.release()
    #expect(await eventually { coordinator.snapshot.items.map(\.timestamp) == [60, 999] })
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func initialHistoryPreemptsAPendingLiveTimer() async {
    let provider = ControlledProvider()
    let config = configuration(provider)
    let coordinator = ChartCoordinator(configuration: config, liveUpdateDelay: 10_000_000_000)
    defer { coordinator.shutdown() }
    coordinator.apply(config, initial: true)
    await provider.streamRequested.wait()
    provider.continuation.yield(RegressionItem(timestamp: 180, close: 3))
    #expect(await eventually { coordinator.rawItems.count == 1 })
    await provider.releasePage.signal()
    #expect(await eventually { coordinator.snapshot.items.map(\.timestamp) == [60, 120, 180] })
}
#endif
