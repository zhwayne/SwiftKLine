//
//  ChartItemLoaderTests.swift
//  SwiftKLineCoreTests
//
//  Created by zhwayne on 2026/10/24.
//

import Foundation
import Testing
@testable import SwiftKLineCore

// MARK: - Fixtures

private struct LoaderCandle: ChartItem {
    let timestamp: Int
    let open: Double = 100
    let high: Double = 101
    let low: Double = 99
    let close: Double = 100
    let volume: Double = 1
    let value: Double = 1
}

/// Records main-actor events for assertions without touching loader state.
@MainActor
private final class EventRecorder {
    private(set) var events: [ChartItemLoader.Event] = []

    func append(_ event: ChartItemLoader.Event) { events.append(event) }

    var pageIndexes: [Int] {
        events.compactMap { if case let .page(index, _) = $0 { return index } else { return nil } }
    }

    var pageCounts: [Int] {
        events.compactMap { if case let .page(_, items) = $0 { return items.count } else { return nil } }
    }

    var liveTimestamps: [Int] {
        events.compactMap { if case let .liveTick(item) = $0 { return item.timestamp } else { return nil } }
    }

    var recoveryCount: Int {
        events.filter { if case .recovery = $0 { return true } else { return false } }.count
    }
}

/// Polls a main-actor condition until it holds or the deadline passes.
@MainActor
private func waitUntil(
    _ description: String,
    timeout: TimeInterval = 2,
    _ condition: @MainActor () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() >= deadline {
            Issue.record("Timed out waiting for \(description)")
            return
        }
        try? await Task.sleep(nanoseconds: 2_000_000)
    }
}

/// Serves fixed pages, an optional recovery interval, and a manually driven live stream.
private final class PagedProvider: ChartItemProvider, @unchecked Sendable {
    private let pages: [[any ChartItem]]
    private let recoveryItems: [any ChartItem]
    private let lock = NSLock()
    private var requestedPages: [Int] = []
    private var liveContinuation: AsyncStream<any ChartItem>.Continuation?
    private var liveSubscriptions = 0

    init(pages: [[any ChartItem]], recovery: [any ChartItem] = []) {
        self.pages = pages
        self.recoveryItems = recovery
    }

    /// `NSLock.lock()` is unavailable in async contexts; keep the critical section in a synchronous helper.
    private func locked<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }

    var pagesRequested: [Int] { locked { requestedPages } }

    var isLiveConnected: Bool { locked { liveContinuation != nil } }

    var subscriptions: Int { locked { liveSubscriptions } }

    func fetchChartItems(forPage page: Int) async throws -> [any ChartItem] {
        locked { requestedPages.append(page) }
        return page < pages.count ? pages[page] : []
    }

    func fetchChartItems(from start: Date, to end: Date) async throws -> [any ChartItem] {
        recoveryItems
    }

    func liveStream() -> AsyncStream<any ChartItem> {
        AsyncStream { continuation in
            locked {
                liveContinuation = continuation
                liveSubscriptions += 1
            }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.locked { self.liveContinuation = nil }
            }
        }
    }

    func emit(_ item: any ChartItem) {
        let continuation = locked { liveContinuation }
        continuation?.yield(item)
    }
}

/// Holds the first page request open so a stop can race an in-flight result.
private final class GatedProvider: ChartItemProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false
    private var requested = false

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }

    var hasRequestedPage: Bool { locked { requested } }

    func release() {
        let pending = locked { () -> CheckedContinuation<Void, Never>? in
            released = true
            defer { continuation = nil }
            return continuation
        }
        pending?.resume()
    }

    func fetchChartItems(forPage page: Int) async throws -> [any ChartItem] {
        locked { requested = true }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let resumeImmediately = locked { () -> Bool in
                if released { return true }
                self.continuation = continuation
                return false
            }
            if resumeImmediately { continuation.resume() }
        }
        return []
    }

    func fetchChartItems(from start: Date, to end: Date) async throws -> [any ChartItem] { [] }
}

// MARK: - Tests

@MainActor
@Suite("Primary candle loading session")
struct ChartItemLoaderTests {

    @Test func historyPagesPublishInOrderUntilAnEmptyPage() async {
        let provider = PagedProvider(pages: [
            [LoaderCandle(timestamp: 60), LoaderCandle(timestamp: 120)],
            [LoaderCandle(timestamp: 180)],
            []
        ])
        let recorder = EventRecorder()
        let loader = ChartItemLoader(provider: provider, enablesLiveUpdates: false,
                                     eventHandler: { recorder.append($0) })

        await loader.start()
        await waitUntil("the first page") { recorder.pageIndexes == [0] }

        await loader.loadMoreIfNeeded(contentOffsetX: 0, viewportWidth: 100)
        await waitUntil("the second page") { recorder.pageIndexes == [0, 1] }

        await loader.loadMoreIfNeeded(contentOffsetX: 0, viewportWidth: 100)
        await waitUntil("the empty page that ends pagination") { recorder.pageIndexes == [0, 1, 2] }

        // The empty page exhausts pagination, so later demand must not refetch.
        await loader.loadMoreIfNeeded(contentOffsetX: 0, viewportWidth: 100)
        try? await Task.sleep(nanoseconds: 30_000_000)

        #expect(recorder.pageIndexes == [0, 1, 2])
        #expect(recorder.pageCounts == [2, 1, 0])
        #expect(provider.pagesRequested == [0, 1, 2])
        await loader.stop()
    }

    @Test func demandFarFromTheLeadingEdgeDoesNotRequestHistory() async {
        let provider = PagedProvider(pages: [[LoaderCandle(timestamp: 60)], [LoaderCandle(timestamp: 120)]])
        let recorder = EventRecorder()
        let loader = ChartItemLoader(provider: provider, enablesLiveUpdates: false,
                                     eventHandler: { recorder.append($0) })

        await loader.start()
        await waitUntil("the first page") { recorder.pageIndexes == [0] }

        await loader.loadMoreIfNeeded(contentOffsetX: 300, viewportWidth: 100)
        try? await Task.sleep(nanoseconds: 30_000_000)
        #expect(recorder.pageIndexes == [0])

        await loader.loadMoreIfNeeded(contentOffsetX: 199, viewportWidth: 100)
        await waitUntil("the page triggered at the threshold") { recorder.pageIndexes == [0, 1] }
        await loader.stop()
    }

    @Test func liveSnapshotsReachTheEventHandler() async {
        let provider = PagedProvider(pages: [[LoaderCandle(timestamp: 60)]])
        let recorder = EventRecorder()
        let loader = ChartItemLoader(provider: provider, eventHandler: { recorder.append($0) })

        await loader.start()
        await waitUntil("the live subscription") { provider.isLiveConnected }

        provider.emit(LoaderCandle(timestamp: 240))
        await waitUntil("the forwarded snapshot") { recorder.liveTimestamps == [240] }
        await loader.stop()
    }

    @Test func stoppingRejectsResultsFromInFlightWork() async {
        let provider = GatedProvider()
        let recorder = EventRecorder()
        let loader = ChartItemLoader(provider: provider, enablesLiveUpdates: false,
                                     eventHandler: { recorder.append($0) })

        await loader.start()
        await waitUntil("the in-flight page request") { provider.hasRequestedPage }

        await loader.stop()
        provider.release()
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(recorder.events.isEmpty)
    }

    @Test func foregroundRecoveryPublishesTheGapBeforeReconnectingLive() async {
        let provider = PagedProvider(pages: [[LoaderCandle(timestamp: 60)]],
                                     recovery: [LoaderCandle(timestamp: 120)])
        let recorder = EventRecorder()
        let loader = ChartItemLoader(provider: provider, eventHandler: { recorder.append($0) })

        await loader.start()
        await waitUntil("the first page") { recorder.pageIndexes == [0] }
        await waitUntil("the live subscription") { provider.isLiveConnected }

        await loader.didEnterBackground(latestTimestamp: 60)
        await loader.willEnterForeground(latestTimestamp: 60)

        await waitUntil("the recovered interval") { recorder.recoveryCount == 1 }
        await waitUntil("a new live subscription") { provider.subscriptions >= 2 }
        await loader.stop()
    }
}
