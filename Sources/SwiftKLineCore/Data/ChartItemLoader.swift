//
//  ChartItemLoader.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2025/04/13.
//

import Foundation

/// Owns a single provider session. Stopping is terminal; replacement requires a fresh loader.
///
/// Request identities reject late results across actor suspension points. Task closures avoid holding
/// the loader strongly across provider waits so disposal does not depend on an uncooperative request completing.
package actor ChartItemLoader {
    /// Sendable events delivered to the main actor, keeping provider work separate from chart-state mutation.
    package enum Event: Sendable {
        case page(index: Int, items: [any ChartItem])
        case recovery(items: [any ChartItem])
        case liveTick(any ChartItem)
        case failed(Failure)
    }

    /// Distinguishes historical-page failures from missing-interval recovery failures.
    package enum Failure: Error {
        case page(Error)
        case recovery(Error)
    }

    package typealias EventHandler = @MainActor @Sendable (Event) -> Void
    private let provider: any ChartItemProvider
    private let eventHandler: EventHandler
    private let enablesLiveUpdates: Bool
    private let enablesGapRecovery: Bool
    private var started = false
    private var stopped = false
    private var suspended = false
    private var activityRevision: UInt64
    private var page = 0
    private var hasMorePages = true
    /// A non-nil task also marks a page as in flight, before another actor message can enqueue duplicate work.
    private var fetchTask: Task<Void, Never>?
    private var liveTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    /// Identity of the active live subscription; invalidated before cancelling its task.
    private var liveID: UUID?
    /// Identity of the active recovery request; rechecked after every event-handler suspension.
    private var recoveryID: UUID?
    private var lastKnownTimestamp: Int?

    package init(provider: some ChartItemProvider, enablesLiveUpdates: Bool = true,
         enablesGapRecovery: Bool = true, initiallyActive: Bool = true,
         activityRevision: UInt64 = 0, eventHandler: @escaping EventHandler) {
        self.provider = provider
        self.enablesLiveUpdates = enablesLiveUpdates
        self.enablesGapRecovery = enablesGapRecovery
        suspended = !initiallyActive
        self.activityRevision = activityRevision
        self.eventHandler = eventHandler
    }

    deinit {
        fetchTask?.cancel()
        liveTask?.cancel()
        recoveryTask?.cancel()
    }

    /// Starts the initial page and optional live subscription once, unless the session has already stopped.
    package func start() {
        guard !started, !stopped else { return }
        started = true
        startLoadingMore()
        startLiveStream()
    }

    /// Permanently stops this session and invalidates all live/recovery identities before cancellation.
    package func stop() {
        stopped = true
        fetchTask?.cancel(); fetchTask = nil
        cancelLiveStream()
        cancelRecovery()
    }

    /// Requests an older page near the leading edge, provided no page is active and pagination is not exhausted.
    package func loadMoreIfNeeded(contentOffsetX: Double, viewportWidth: Double) {
        guard started, !stopped, contentOffsetX < viewportWidth * 2 else { return }
        startLoadingMore()
    }

    /// Remembers a recovery boundary and suspends live consumption and any in-flight recovery.
    package func didEnterBackground(latestTimestamp: Int?) {
        guard !stopped else { return }
        suspended = true
        lastKnownTimestamp = latestTimestamp ?? lastKnownTimestamp
        cancelLiveStream()
        cancelRecovery()
    }

    /// Revisioned activity commands cannot be undone by an older actor hop arriving late.
    package func setActive(_ value: Bool, latestTimestamp: Int?, revision: UInt64) {
        guard !stopped, revision > activityRevision else { return }
        activityRevision = revision
        if value { willEnterForeground(latestTimestamp: latestTimestamp) }
        else { didEnterBackground(latestTimestamp: latestTimestamp) }
    }

    /// Recovers the missing interval when possible, then reconnects live data without overlapping the two sources.
    package func willEnterForeground(latestTimestamp: Int?) {
        guard !stopped else { return }
        suspended = false
        recoverIfActive(latestTimestamp: latestTimestamp)
    }

    /// Connectivity recovery does not change visibility or reactivate a suspended session.
    package func recoverIfActive(latestTimestamp: Int?) {
        guard started, !stopped, !suspended, recoveryTask == nil else { return }
        guard enablesGapRecovery, let timestamp = latestTimestamp ?? lastKnownTimestamp else {
            startLiveStream()
            return
        }
        // Recovery precedes reconnection, so an older HTTP snapshot cannot overwrite a newer live tick.
        cancelLiveStream()
        let id = UUID()
        recoveryID = id
        let provider = provider
        recoveryTask = Task { [weak self] in
            do {
                let items = try await provider.fetchChartItems(
                    from: Date(timeIntervalSince1970: TimeInterval(timestamp)), to: Date())
                guard !Task.isCancelled else { return }
                await self?.completeRecovery(id: id, result: .success(items))
            } catch {
                guard !Task.isCancelled else { return }
                await self?.completeRecovery(id: id, result: .failure(error))
            }
        }
    }

    private func startLoadingMore() {
        guard started, !stopped, hasMorePages, fetchTask == nil else { return }
        let requestPage = page
        let provider = provider
        // Mark loading synchronously by installing the task before another actor message can arrive.
        fetchTask = Task { [weak self] in
            do {
                let items = try await provider.fetchChartItems(forPage: requestPage)
                guard !Task.isCancelled else { return }
                await self?.completePage(index: requestPage, result: .success(items))
            } catch {
                guard !Task.isCancelled else { return }
                await self?.completePage(index: requestPage, result: .failure(error))
            }
        }
    }

    /// Commits a page outcome only for an active session; even an empty initial page establishes the baseline.
    private func completePage(index: Int, result: Result<[any ChartItem], Error>) async {
        guard !stopped, !Task.isCancelled else { return }
        fetchTask = nil
        switch result {
        case let .success(items):
            // An empty initial page still establishes the baseline and releases buffered live ticks.
            hasMorePages = !items.isEmpty
            page += 1
            await eventHandler(.page(index: index, items: items))
        case let .failure(error): await eventHandler(.failed(.page(error)))
        }
    }

    private func startLiveStream() {
        guard enablesLiveUpdates, started, !stopped, !suspended, liveTask == nil else { return }
        let provider = provider
        let id = UUID()
        liveID = id
        liveTask = Task { [weak self] in
            for await tick in provider.liveStream() {
                guard !Task.isCancelled else { break }
                guard let self else { break }
                await self.handleLiveTick(tick, id: id)
            }
            await self?.liveStreamFinished(id: id)
        }
    }

    private func handleLiveTick(_ tick: any ChartItem, id: UUID) async {
        guard !stopped, !suspended, liveID == id, !Task.isCancelled else { return }
        lastKnownTimestamp = max(lastKnownTimestamp ?? tick.timestamp, tick.timestamp)
        await eventHandler(.liveTick(tick))
    }

    private func liveStreamFinished(id: UUID) {
        guard liveID == id else { return }
        liveTask = nil
        liveID = nil
    }

    /// Publishes recovery results and rechecks its identity after the main-actor handler before reconnecting live data.
    private func completeRecovery(id: UUID, result: Result<[any ChartItem], Error>) async {
        guard !stopped, !suspended, recoveryID == id, !Task.isCancelled else { return }
        switch result {
        case let .success(items):
            if !items.isEmpty { await eventHandler(.recovery(items: items)) }
        case let .failure(error): await eventHandler(.failed(.recovery(error)))
        }
        // The event handler suspends this actor; a background/stop event may have invalidated the request.
        guard !stopped, !suspended, recoveryID == id else { return }
        recoveryTask = nil
        recoveryID = nil
        startLiveStream()
    }

    private func cancelLiveStream() {
        liveID = nil
        liveTask?.cancel(); liveTask = nil
    }

    private func cancelRecovery() {
        recoveryID = nil
        recoveryTask?.cancel(); recoveryTask = nil
    }
}
