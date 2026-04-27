//
//  KLineItemLoader.swift
//  SwiftKLine
//
//  Created by iya on 2025/4/13.
//

import Foundation

enum KLineItemLoaderEvent {
    case page(index: Int, items: [any KLineItem])
    case recovery(items: [any KLineItem])
    case liveTick(any KLineItem)
    case failed(KLineItemLoaderError)
}

enum KLineItemLoaderError: Error {
    case page(Error)
    case recovery(Error)
}

actor KLineItemLoader {
    typealias EventHandler = @MainActor (KLineItemLoaderEvent) -> Void

    private let provider: any KLineItemProvider
    private let eventHandler: EventHandler

    private var page = 0
    private var isLoading = false
    private var hasMorePages = true
    private var fetchTask: Task<Void, Never>?
    private var liveTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private var lastKnownTimestamp: Int?
    private var isRecovering = false

    init(
        provider: some KLineItemProvider,
        eventHandler: @escaping EventHandler
    ) {
        self.provider = provider
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
        startLiveStream()
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
        guard let timestamp = latestTimestamp ?? lastKnownTimestamp else {
            startLiveStream()
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
            let items = try await provider.fetchKLineItems(forPage: currentPage)
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
            let missing = try await provider.fetchKLineItems(from: startDate, to: Date())
            guard !Task.isCancelled else { return }
            if !missing.isEmpty {
                await eventHandler(.recovery(items: missing))
            }
        } catch {
            guard !Task.isCancelled else { return }
            await eventHandler(.failed(.recovery(error)))
        }
        startLiveStream()
    }
}
