//
//  ChartItemLoader.swift
//  SwiftKLine
//
//  Created by iya on 2025/4/13.
//

import Foundation

enum DataLoaderEvent {
    case page(index: Int, items: [any ChartItem])
    case recovery(items: [any ChartItem])
    case liveTick(any ChartItem)
    case failed(DataLoaderError)
}

enum DataLoaderError: Error {
    case page(Error)
    case recovery(Error)
}

actor ChartItemLoader {
    typealias EventHandler = @MainActor (DataLoaderEvent) -> Void

    private let provider: any ChartItemProvider
    private let eventHandler: EventHandler
    private let enablesLiveUpdates: Bool
    private let enablesGapRecovery: Bool

    private var page = 0
    private var isLoading = false
    private var hasMorePages = true
    private var fetchTask: Task<Void, Never>?
    private var liveTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private var lastKnownTimestamp: Int?
    private var isRecovering = false

    init(
        provider: some ChartItemProvider,
        enablesLiveUpdates: Bool = true,
        enablesGapRecovery: Bool = true,
        eventHandler: @escaping EventHandler
    ) {
        self.provider = provider
        self.enablesLiveUpdates = enablesLiveUpdates
        self.enablesGapRecovery = enablesGapRecovery
        self.eventHandler = eventHandler
    }

    deinit {
        fetchTask?.cancel()
        liveTask?.cancel()
        recoveryTask?.cancel()
    }

    func loadMoreIfNeeded(contentOffsetX: Double, viewportWidth: Double) {
        guard !isLoading, hasMorePages else { return }
        guard contentOffsetX < viewportWidth * 2 else { return }
        startLoadingMore()
    }

    func start() {
        page = 0
        hasMorePages = true
        isLoading = false
        startLoadingMore()
        if enablesLiveUpdates {
            startLiveStream()
        }
    }

    func stop() {
        fetchTask?.cancel()
        liveTask?.cancel()
        recoveryTask?.cancel()
        fetchTask = nil
        liveTask = nil
        recoveryTask = nil
        isLoading = false
        isRecovering = false
    }

    func didEnterBackground(latestTimestamp: Int?) {
        lastKnownTimestamp = latestTimestamp
        liveTask?.cancel()
        liveTask = nil
    }

    func willEnterForeground(latestTimestamp: Int?) {
        guard enablesGapRecovery else {
            if enablesLiveUpdates {
                startLiveStream()
            }
            return
        }
        guard let timestamp = latestTimestamp ?? lastKnownTimestamp else {
            if enablesLiveUpdates {
                startLiveStream()
            }
            return
        }
        guard !isRecovering else { return }
        recoveryTask?.cancel()
        recoveryTask = Task { [weak self] in
            await self?.recoverMissingData(from: timestamp)
        }
    }

    private func startLoadingMore() {
        guard hasMorePages else { return }
        fetchTask?.cancel()
        fetchTask = Task { [weak self] in
            await self?.loadMore()
        }
    }

    private func loadMore() async {
        guard !isLoading, hasMorePages else { return }
        isLoading = true
        let currentPage = page
        defer { isLoading = false }

        do {
            let items = try await provider.fetchChartItems(forPage: currentPage)
            guard !Task.isCancelled else { return }
            guard !items.isEmpty else {
                hasMorePages = false
                return
            }
            page += 1
            await eventHandler(.page(index: currentPage, items: items))
        } catch {
            guard !Task.isCancelled else { return }
            await eventHandler(.failed(.page(error)))
        }
    }

    private func startLiveStream() {
        guard enablesLiveUpdates else { return }
        liveTask?.cancel()
        liveTask = Task { [weak self] in
            await self?.consumeLiveStream()
        }
    }

    private func consumeLiveStream() async {
        for await tick in provider.liveStream() {
            guard !Task.isCancelled else { break }
            lastKnownTimestamp = tick.timestamp
            await eventHandler(.liveTick(tick))
        }
    }

    private func recoverMissingData(from timestamp: Int) async {
        guard !isRecovering else { return }
        isRecovering = true
        defer {
            isRecovering = false
            lastKnownTimestamp = nil
        }

        do {
            let startDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
            let missing = try await provider.fetchChartItems(from: startDate, to: Date())
            guard !Task.isCancelled else { return }
            if !missing.isEmpty {
                await eventHandler(.recovery(items: missing))
            }
        } catch {
            guard !Task.isCancelled else { return }
            await eventHandler(.failed(.recovery(error)))
        }
        if enablesLiveUpdates {
            startLiveStream()
        }
    }
}
