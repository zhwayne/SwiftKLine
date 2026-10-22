//
//  RangeLoaderTests.swift
//  SwiftKLineCoreTests
//
//  Created by zhwayne on 2026/10/21.
//

import Foundation
import Testing
@testable import SwiftKLineCore

private struct SampleItem: Sendable {
    let id: String
    let timestamp: Date
    let value: Double
}

private func date(_ seconds: Double) -> Date { Date(timeIntervalSince1970: seconds) }
private func range(_ start: Double, _ end: Double) -> Range<Date> { date(start)..<date(end) }
private func item(_ id: String, _ seconds: Double, _ value: Double = 1) -> SampleItem {
    SampleItem(id: id, timestamp: date(seconds), value: value)
}

@MainActor private final class Publications {
    private var values: [RangeSnapshot<SampleItem>] = []
    private var waiting: [((RangeSnapshot<SampleItem>) -> Bool, CheckedContinuation<RangeSnapshot<SampleItem>, Never>)] = []
    func append(_ value: RangeSnapshot<SampleItem>) {
        values.append(value)
        let ready = waiting.filter { $0.0(value) }
        waiting.removeAll { $0.0(value) }
        for (_, continuation) in ready { continuation.resume(returning: value) }
    }
    func wait(_ predicate: @escaping (RangeSnapshot<SampleItem>) -> Bool) async -> RangeSnapshot<SampleItem> {
        if let value = values.last, predicate(value) { return value }
        return await withCheckedContinuation { waiting.append((predicate, $0)) }
    }
}

private actor Pages: RangeDataProvider {
    enum Mode { case paged, empty, failOnce, cycle, pair, overflow }
    enum Failure: Error { case offline }
    let mode: Mode
    private(set) var requests: [(Range<Date>, Int?)] = []
    private var failed = false
    init(_ mode: Mode) { self.mode = mode }
    func fetch(in range: Range<Date>, cursor: Int?) async throws -> RangePage<SampleItem, Int> {
        requests.append((range, cursor))
        let start = range.lowerBound.timeIntervalSince1970
        switch mode {
        case .empty: return RangePage(items: [], nextCursor: nil)
        case .pair:
            return RangePage(items: [item("\(start)-a", start + 10), item("\(start)-b", start + 20)], nextCursor: nil)
        case .overflow:
            return RangePage(items: [item("a", 10), item("b", 20), item("c", 30)], nextCursor: nil)
        case .cycle: return RangePage(items: [], nextCursor: 1)
        case .failOnce:
            if cursor == nil { return RangePage(items: [item("a", 10)], nextCursor: 1) }
            if !failed { failed = true; throw Failure.offline }
            return RangePage(items: [item("b", 20)], nextCursor: nil)
        case .paged:
            if cursor == nil { return RangePage(items: [item("b", 20), item("a", 10)], nextCursor: 1) }
            if cursor == 1 { return RangePage(items: [], nextCursor: 2) }
            return RangePage(items: [item("a", 10, 9), item("c", 30)], nextCursor: nil)
        }
    }
}

@MainActor private func loader(_ provider: Pages, _ publications: Publications, capacity: Int = 20_000) -> RangeLoader<Pages, String> {
    RangeLoader(provider: provider, maxCachedItems: capacity, identity: { $0.id }, timestamp: { $0.timestamp },
                onUpdate: { publications.append($0) })
}

@available(macOS 13.0, iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func rangePagesPublishDuplicatesAndContinueAcrossEmptyPages() async {
    let provider = Pages(.paged), publications = Publications()
    let loader = loader(provider, publications)
    let query = range(0, 100)
    await loader.load(in: query)
    let result = await publications.wait { $0.completedRanges == [query] }
    #expect(result.items.map(\.id) == ["a", "b", "c"])
    #expect(result.items.first?.value == 9)
    #expect(await provider.requests.map { $0.1 } == [nil, 1, 2])
    await loader.load(in: query)
    #expect(await provider.requests.count == 3)
}

@available(macOS 13.0, iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func emptyQueriesAreCoveredAndOverlappingDemandFetchesOnlyTheGap() async {
    let provider = Pages(.empty), publications = Publications()
    let loader = loader(provider, publications)
    await loader.load(in: range(0, 100))
    _ = await publications.wait { $0.completedRanges == [range(0, 100)] }
    await loader.load(in: range(50, 150))
    _ = await publications.wait { $0.completedRanges == [range(0, 150)] }
    #expect(await provider.requests.map { $0.0 } == [range(0, 100), range(100, 150)])
}

@available(macOS 13.0, iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func rangeFailureRetriesTheSameCursorAndDoesNotClaimCoverage() async {
    let provider = Pages(.failOnce), publications = Publications()
    let loader = loader(provider, publications)
    await loader.load(in: range(0, 100))
    let failed = await publications.wait { $0.error != nil }
    #expect(failed.completedRanges.isEmpty)
    #expect(failed.items.count == 1)
    await loader.retry()
    let result = await publications.wait { !$0.completedRanges.isEmpty }
    #expect(result.items.count == 2)
    #expect(await provider.requests.map { $0.1 } == [nil, 1, 1])
}

@available(macOS 13.0, iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func repeatedCursorTerminatesTheQuery() async {
    let provider = Pages(.cycle), publications = Publications()
    let loader = loader(provider, publications)
    await loader.load(in: range(0, 100))
    let result = await publications.wait { $0.error != nil }
    #expect(result.error as? RangeLoadingError == .repeatedCursor)
    #expect(result.completedRanges.isEmpty)
    #expect(await provider.requests.count == 2)
}

@available(macOS 13.0, iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func cacheEvictionAlsoInvalidatesCoverage() async {
    let provider = Pages(.pair), publications = Publications()
    let loader = loader(provider, publications, capacity: 2)
    await loader.load(in: range(0, 100))
    _ = await publications.wait { $0.completedRanges == [range(0, 100)] }
    await loader.load(in: range(100, 200))
    let result = await publications.wait { $0.completedRanges == [range(100, 200)] }
    #expect(result.items.map(\.timestamp) == [date(110), date(120)])
    await loader.load(in: range(0, 100))
    _ = await publications.wait { $0.items.first?.timestamp == date(10) && $0.completedRanges == [range(0, 100)] }
    #expect(await provider.requests.count == 3)
}

@available(macOS 13.0, iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func capacityOverflowStopsInsteadOfRefetchingForever() async {
    let provider = Pages(.overflow), publications = Publications()
    let loader = loader(provider, publications, capacity: 2)
    await loader.load(in: range(0, 100))
    let result = await publications.wait { $0.error != nil }
    #expect(result.error as? RangeLoadingError == .cacheCapacityExceeded)
    #expect(result.items.count == 2)
    #expect(result.completedRanges.isEmpty)
    await loader.load(in: range(0, 100))
    #expect(await provider.requests.count == 1)
}

private actor Gate {
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async { if !opened { await withCheckedContinuation { waiters.append($0) } } }
    func open() { opened = true; let pending = waiters; waiters = []; pending.forEach { $0.resume() } }
}
private actor SuspendedPages: RangeDataProvider {
    let requested = Gate(), release = Gate()
    func fetch(in range: Range<Date>, cursor: Int?) async throws -> RangePage<SampleItem, Int> {
        await requested.open()
        await release.wait()
        return RangePage(items: [item("late", 10)], nextCursor: nil)
    }
}

@available(macOS 13.0, iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) func releasingRangeLoaderDoesNotWaitForAnUncooperativeProvider() async {
    let provider = SuspendedPages()
    var loader: RangeLoader<SuspendedPages, String>? = RangeLoader(provider: provider,
        identity: { $0.id }, timestamp: { $0.timestamp }, onUpdate: { _ in })
    weak var reference: RangeLoader<SuspendedPages, String>?
    reference = loader
    await loader?.load(in: range(0, 100))
    await provider.requested.wait()
    loader = nil
    #expect(reference == nil)
    await provider.release.open()
}

@available(macOS 13.0, iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func stoppingRangeLoaderRejectsLateResults() async {
    let provider = SuspendedPages()
    var publications = 0
    let loader = RangeLoader(provider: provider, identity: { $0.id }, timestamp: { $0.timestamp },
                             onUpdate: { _ in publications += 1 })
    await loader.load(in: range(0, 100))
    await provider.requested.wait()
    await loader.stop()
    await provider.release.open()
    for _ in 0..<20 { await Task.yield() }
    #expect(publications == 0)
    #expect(await loader.snapshot.items.isEmpty)
}

private actor FailingOlderPages: RangeDataProvider {
    enum Failure: Error { case offline }
    let requested = Gate(), release = Gate()
    private(set) var ranges: [Range<Date>] = []
    func fetch(in range: Range<Date>, cursor: Int?) async throws -> RangePage<SampleItem, Int> {
        ranges.append(range)
        if range.lowerBound == date(0) {
            await requested.open(); await release.wait()
            throw Failure.offline
        }
        return RangePage(items: [], nextCursor: nil)
    }
}

@available(macOS 13.0, iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func obsoleteQueryFailureDoesNotBlockTheLatestViewport() async {
    let provider = FailingOlderPages(), publications = Publications()
    let loader = RangeLoader(provider: provider, identity: { $0.id }, timestamp: { $0.timestamp },
                             onUpdate: { publications.append($0) })
    await loader.load(in: range(0, 100))
    await provider.requested.wait()
    await loader.load(in: range(100, 200))
    await provider.release.open()
    let result = await publications.wait { $0.completedRanges == [range(100, 200)] }
    #expect(result.error == nil)
    #expect(await provider.ranges == [range(0, 100), range(100, 200)])
}
