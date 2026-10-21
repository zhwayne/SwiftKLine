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

@MainActor private func makeCoordinator() -> ChartCoordinator {
    let config = ChartConfiguration()
    return ChartCoordinator(configuration: config, features: [.liveUpdates], indicatorPipeline: IndicatorPipeline(
        configuration: config,
        normalizer: IndicatorSelectionNormalizer(availableMain: [], availableSub: []),
        selectionStore: nil,
        registry: .default
    ))
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func initialPagePreservesNewAndUpdatedLiveCandles() async {
    let provider = ControlledProvider()
    let coordinator = makeCoordinator()
    let receivedTicks = Signal()
    let receivedPage = Signal()
    coordinator.onStateUpdated = { state, _, event in
        if case .liveTick = event, state.items.count == 2 {
            Task { await receivedTicks.signal() }
        }
        if case .page = event { Task { await receivedPage.signal() } }
    }
    coordinator.loadData(using: provider)
    await provider.streamRequested.wait()
    provider.continuation.yield(RegressionItem(timestamp: 120, close: 20))
    provider.continuation.yield(RegressionItem(timestamp: 120, close: 22))
    provider.continuation.yield(RegressionItem(timestamp: 180, close: 3))
    await receivedTicks.wait()
    await provider.releasePage.signal()
    await receivedPage.wait()

    #expect(coordinator.state.items.map(\.timestamp) == [60, 120, 180])
    #expect(coordinator.state.items.map(\.close) == [1, 22, 3])
    coordinator.stopDataLoading()
    await provider.terminated.wait()
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) func releasingLoaderCancelsInfiniteStream() async {
    let provider = ControlledProvider()
    // Complete history first so the test isolates whether an infinite stream retains its loader.
    await provider.releasePage.signal()
    var loader: ChartItemLoader? = ChartItemLoader(provider: provider, eventHandler: { _ in })
    weak var weakLoader = loader
    await loader?.start()
    await provider.streamRequested.wait()
    loader = nil
    await provider.terminated.wait()
    #expect(weakLoader == nil)
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func stoppingCoordinatorTerminatesLiveSubscription() async {
    let provider = ControlledProvider()
    await provider.releasePage.signal()
    let coordinator = makeCoordinator()
    coordinator.loadData(using: provider)
    await provider.streamRequested.wait()
    coordinator.stopDataLoading()
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
    func calculate(for items: [any ChartItem]) -> [Double?] {
        if items.first?.timestamp == 999 { gate.block() }
        return items.map { $0.close }
    }
}

/// Installs the gated calculator under either a custom or replaced built-in ID for lifecycle regression tests.
private struct GatedPlugin: IndicatorPlugin {
    let id: IndicatorID
    let title = "Gated"
    let placement: IndicatorPlacement = .main
    let defaultSeriesKeys = [SeriesKey(indicatorID: "test.gated", name: "gated")]
    let gate: CalculationGate
    func makeCalculators(configuration: ChartConfiguration) -> [any IndicatorCalculator] { [GatedCalculator(gate: gate)] }
    func makeRenderers(configuration: ChartConfiguration) -> [any ChartRenderer] { [] }
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func oldDrawCannotRestoreItemsAfterProviderReplacement() async {
    let gate = CalculationGate()
    defer { gate.release() }
    let registry = PluginRegistry.default
    registry.register(GatedPlugin(id: "test.gated", gate: gate))
    let view = ChartView(options: ChartOptions(
        indicators: IndicatorSelectionState(mainIndicatorIDs: ["test.gated"]), features: [], plugins: registry
    ))
    let oldDraw = Task { await view.debugDraw(items: [RegressionItem(timestamp: 999, close: 99)]) }
    for await _ in gate.started { break }
    let provider = ControlledProvider()
    view.loadData(using: provider)
    gate.release()
    await oldDraw.value
    #expect(view.debugCoordinatorItemTimestamps.isEmpty)
    #expect(view.debugItemTimestamps.isEmpty)
    // Release the pending history request so the test leaves no suspended producer task.
    await provider.releasePage.signal()
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func oldCalculationCannotOverwriteNewIndicatorValues() async {
    let gate = CalculationGate()
    defer { gate.release() }
    let registry = PluginRegistry.default
    registry.register(GatedPlugin(id: "test.gated", gate: gate))
    let view = ChartView(options: ChartOptions(
        indicators: IndicatorSelectionState(mainIndicatorIDs: ["test.gated"]), features: [], plugins: registry
    ))
    let oldDraw = Task { await view.debugDraw(items: [RegressionItem(timestamp: 999, close: 99)]) }
    for await _ in gate.started { break }
    await view.debugDraw(items: [RegressionItem(timestamp: 60, close: 7)])
    gate.release()
    await oldDraw.value
    #expect(view.debugCoordinatorItemTimestamps == [60])
    #expect(view.debugIndicatorSeriesStore.values(for: SeriesKey(indicatorID: "test.gated", name: "gated"), as: Double.self) == [7])
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func replacementBuiltInPluginSuppliesItsOwnCalculator() async {
    let gate = CalculationGate()
    let registry = PluginRegistry.default
    registry.register(GatedPlugin(id: .ma, gate: gate))
    let config = ChartConfiguration()
    let pipeline = IndicatorPipeline(configuration: config,
        normalizer: IndicatorSelectionNormalizer(availableMain: [.ma], availableSub: []),
        selectionStore: nil, registry: registry)
    let store = await pipeline.calculate(items: [RegressionItem(timestamp: 60, close: 7)],
        selection: IndicatorSelectionState(mainIndicatorIDs: [.ma]))
    #expect(store.values(for: SeriesKey(indicatorID: "test.gated", name: "gated"), as: Double.self) == [7])
    #expect(store.values(for: .ma(period: 5), as: Double.self) == nil)
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
@Test(.timeLimit(.minutes(1))) @MainActor
func ticksDuringSlowCalculationAreEventuallyPublished() async {
    let gate = CalculationGate()
    defer { gate.release() }
    let registry = PluginRegistry.default
    registry.register(GatedPlugin(id: "test.gated", gate: gate))
    let view = ChartView(options: ChartOptions(
        indicators: IndicatorSelectionState(mainIndicatorIDs: ["test.gated"]), features: [], plugins: registry))
    view.setItems([RegressionItem(timestamp: 999, close: 1)])
    for await _ in gate.started { break }
    view.update(RegressionItem(timestamp: 999, close: 7))
    view.update(RegressionItem(timestamp: 1000, close: 8))
    gate.release()
    await view.debugWaitForRefresh()
    #expect(view.debugRenderedCloses == [7, 8])
    #expect(view.debugIndicatorSeriesStore.values(for: SeriesKey(indicatorID: "test.gated", name: "gated"), as: Double.self) == [7, 8])
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor
func emptyInitialPageStillReplaysLiveTicks() async {
    let provider = ControlledProvider(initialItems: [])
    let coordinator = makeCoordinator()
    let tickReceived = Signal()
    let pageReceived = Signal()
    coordinator.onStateUpdated = { _, _, event in
        if case .liveTick = event { Task { await tickReceived.signal() } }
        if case .page = event { Task { await pageReceived.signal() } }
    }
    coordinator.loadData(using: provider)
    await provider.streamRequested.wait()
    provider.continuation.yield(RegressionItem(timestamp: 60, close: 7))
    await tickReceived.wait()
    await provider.releasePage.signal()
    await pageReceived.wait()
    #expect(coordinator.state.items.map(\.close) == [7])
    coordinator.stopDataLoading()
    await provider.terminated.wait()
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1)))
func releasingLoaderDoesNotWaitForUncooperativePageRequest() async {
    let provider = ControlledProvider()
    var loader: ChartItemLoader? = ChartItemLoader(provider: provider, enablesLiveUpdates: false, eventHandler: { _ in })
    await loader?.start()
    await provider.pageRequested.wait()
    weak var weakLoader = loader
    loader = nil
    #expect(weakLoader == nil)
    await provider.releasePage.signal()
}

#endif
