//
//  RangeLoader.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2026/10/21.
//

import Foundation

/// Loads independent ranges with one owned request, explicit coverage, and bounded storage.
///
/// Pages may publish progressively. Completion is recorded only after a nil next cursor.
/// Network tasks capture this actor weakly across provider suspension; stop is terminal.
public actor RangeLoader<Provider: RangeDataProvider, ID: Hashable & Sendable> {
    /// Receives immutable publications on the main actor without exposing loader state.
    public typealias Handler = @MainActor @Sendable (RangeSnapshot<Provider.Item>) -> Void
    private struct Query {
        let range: Range<Date>
        var cursor: Provider.Cursor?
        var visited: Set<Provider.Cursor> = []
        var lostData = false
    }
    private struct Entry {
        let value: Provider.Item
        let order: UInt64
    }
    private let provider: Provider
    private let identity: @Sendable (Provider.Item) -> ID
    private let timestamp: @Sendable (Provider.Item) -> Date
    private let maxItems: Int
    private let maxRanges: Int
    private var handler: Handler?
    private var cache: [ID: Entry] = [:]
    private var sequence: UInt64 = 0
    private var completed: [Range<Date>] = []
    private var demand: Range<Date>?
    private var query: Query?
    private var task: Task<Void, Never>?
    private var requestID: UUID?
    private var active = true
    private var stopped = false
    private var failed = false
    private var lastError: (any Error)?
    private var sortedItems: [Provider.Item] = []

    /// Creates an isolated cache with explicit identity/time extraction and hard capacity limits.
    public init(provider: Provider, maxCachedItems: Int = 20_000, maxCachedRanges: Int = 64,
                identity: @escaping @Sendable (Provider.Item) -> ID,
                timestamp: @escaping @Sendable (Provider.Item) -> Date,
                onUpdate: @escaping Handler) {
        precondition(maxCachedItems > 0 && maxCachedRanges > 0)
        self.provider = provider; self.identity = identity; self.timestamp = timestamp
        maxItems = maxCachedItems; maxRanges = maxCachedRanges; handler = onUpdate
    }

    deinit { task?.cancel() }

    /// The latest time-sorted values and exact query completion state.
    public var snapshot: RangeSnapshot<Provider.Item> {
        RangeSnapshot(items: sortedItems, completedRanges: completed,
                      isLoading: task != nil || (query != nil && active && !failed), error: lastError)
    }

    /// Replaces demand, coalescing rapid viewport updates without starting duplicate pages.
    public func load(in range: Range<Date>) {
        guard !stopped, !range.isEmpty else { return }
        if demand != range, failed {
            query = nil; failed = false; lastError = nil
        }
        demand = range
        advance()
    }

    /// Retries the same failed cursor without claiming the query is complete.
    public func retry() {
        guard !stopped else { return }
        failed = false; lastError = nil
        advance()
    }

    /// Pauses requests while retaining partial query state and completed coverage.
    public func setActive(_ value: Bool) {
        guard !stopped, value != active else { return }
        active = value
        if value { advance() }
        else { requestID = nil; task?.cancel(); task = nil }
    }

    /// Permanently cancels this session and invalidates all late request results.
    public func stop() {
        stopped = true; requestID = nil
        task?.cancel(); task = nil
        handler = nil; query = nil
    }

    private func missing(in range: Range<Date>) -> Range<Date>? {
        var start = range.lowerBound
        for covered in completed {
            if covered.upperBound <= start { continue }
            if covered.lowerBound >= range.upperBound { break }
            if covered.lowerBound > start { return start..<min(covered.lowerBound, range.upperBound) }
            start = max(start, covered.upperBound)
            if start >= range.upperBound { return nil }
        }
        return start < range.upperBound ? start..<range.upperBound : nil
    }

    private func advance() {
        guard !stopped, active, !failed, task == nil, let demand else { return }
        if query == nil {
            guard let missing = missing(in: demand) else { return }
            query = Query(range: missing)
        }
        guard var query else { return }
        if let cursor = query.cursor { query.visited.insert(cursor) }
        self.query = query
        let provider = provider
        let id = UUID(); requestID = id
        task = Task { [weak self] in
            do {
                let page = try await provider.fetch(in: query.range, cursor: query.cursor)
                guard !Task.isCancelled else { return }
                await self?.complete(id: id, result: .success(page))
            } catch {
                guard !Task.isCancelled else { return }
                await self?.complete(id: id, result: .failure(error))
            }
        }
    }

    private func complete(id: UUID, result: Result<RangePage<Provider.Item, Provider.Cursor>, Error>) async {
        guard !stopped, active, requestID == id, var query else { return }
        task = nil; requestID = nil
        var finishedRange: Range<Date>?
        switch result {
        case let .failure(error):
            lastError = error
            if let demand, !query.range.overlaps(demand) {
                // A failed obsolete viewport must not block the latest unrelated demand.
                self.query = nil
            } else { failed = true }
        case let .success(page):
            lastError = nil
            for item in page.items where query.range.contains(timestamp(item)) {
                let key = identity(item)
                let order = cache[key]?.order ?? sequence
                if cache[key] == nil { sequence &+= 1 }
                cache[key] = Entry(value: item, order: order)
            }
            if let cursor = page.nextCursor {
                if query.visited.contains(cursor) {
                    failed = true; lastError = RangeLoadingError.repeatedCursor
                } else { query.cursor = cursor }
                self.query = query
            } else {
                if !query.lostData { finishedRange = query.range }
                self.query = nil
            }
            let lostData = evict(finishing: finishedRange)
            if let finishedRange, !lostData { addCoverage(finishedRange) }
            sortedItems = cache.values.sorted {
                let left = timestamp($0.value), right = timestamp($1.value)
                return left == right ? $0.order < $1.order : left < right
            }.map(\.value)
        }
        if let handler { await handler(snapshot) }
        // The handler suspends this actor; use current state after stop, pause, or demand updates.
        advance()
    }

    private func addCoverage(_ range: Range<Date>) {
        var result: [Range<Date>] = []
        for interval in (completed + [range]).sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = result.last, interval.lowerBound <= last.upperBound {
                result[result.count - 1] = last.lowerBound..<max(last.upperBound, interval.upperBound)
            } else { result.append(interval) }
        }
        completed = Array(result.suffix(maxRanges))
    }

    /// Eviction removes coverage too, so revisiting an evicted interval can fetch it again.
    private func evict(finishing: Range<Date>?) -> Bool {
        guard cache.count > maxItems, let demand else { return false }
        var lostFinishingData = false
        let center = demand.lowerBound.timeIntervalSince1970 / 2 + demand.upperBound.timeIntervalSince1970 / 2
        let candidates = cache.sorted {
            let left = timestamp($0.value.value), right = timestamp($1.value.value)
            let leftVisible = demand.contains(left), rightVisible = demand.contains(right)
            if leftVisible != rightVisible { return !leftVisible }
            let leftDistance = abs(left.timeIntervalSince1970 - center)
            let rightDistance = abs(right.timeIntervalSince1970 - center)
            return leftDistance == rightDistance ? $0.value.order < $1.value.order : leftDistance > rightDistance
        }
        for (key, entry) in candidates.prefix(cache.count - maxItems) {
            let date = timestamp(entry.value)
            if demand.contains(date) { failed = true; lastError = RangeLoadingError.cacheCapacityExceeded }
            if query?.range.contains(date) == true { query?.lostData = true }
            lostFinishingData = lostFinishingData || finishing?.contains(date) == true
            completed.removeAll { $0.contains(date) }
            cache.removeValue(forKey: key)
        }
        return lostFinishingData
    }
}
