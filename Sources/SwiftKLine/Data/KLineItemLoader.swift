//
//  KLineItemLoader.swift
//  SwiftKLine
//
//  Created by iya on 2025/4/13.
//

import UIKit

final class KLineItemLoader: @unchecked Sendable {
    typealias SnapshotHandler = @Sendable (Int, [any KLineItem]) async -> Void
    typealias LiveHandler = @Sendable (any KLineItem) async -> Void

    private let provider: any KLineItemProvider
    private let snapshotHandler: SnapshotHandler
    private let liveHandler: LiveHandler

    private var page = 0
    private var isLoading = false
    private var fetchTask: Task<Void, Never>?
    private var liveTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private var lastKnownTimestamp: Int?
    private var isRecovering = false

    init(
        provider: some KLineItemProvider,
        snapshotHandler: @escaping SnapshotHandler,
        liveHandler: @escaping LiveHandler
    ) {
        self.provider = provider
        self.snapshotHandler = snapshotHandler
        self.liveHandler = liveHandler
    }

    deinit {
        fetchTask?.cancel()
        liveTask?.cancel()
        recoveryTask?.cancel()
    }

    @MainActor
    func scrollViewDidScroll(scrollView: UIScrollView) {
        guard !isLoading else { return }
        let offsetX = scrollView.contentOffset.x
        let width = scrollView.bounds.width
        guard offsetX < width * 2 else { return }
        loadMore()
    }

    func start() {
        page = 0
        loadMore()
        startLiveStream()
    }

    func stop() {
        fetchTask?.cancel()
        liveTask?.cancel()
        recoveryTask?.cancel()
        fetchTask = nil
        liveTask = nil
        recoveryTask = nil
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
            guard let self else { return }
            let startDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
            await self.recoverMissingData(from: startDate, to: Date())
        }
    }

    private func loadMore() {
        isLoading = true
        fetchTask?.cancel()
        fetchTask = Task { [weak self] in
            guard let self else { return }
            defer { self.isLoading = false }
            do {
                let items = try await self.provider.fetchKLineItems(forPage: self.page)
                guard !items.isEmpty else { return }
                await self.snapshotHandler(self.page, items)
                self.page += 1
            } catch {
                print("KLineItemLoader load error: \(error)")
            }
        }
    }

    private func startLiveStream() {
        liveTask?.cancel()
        liveTask = Task { [weak self] in
            guard let self else { return }
            for await tick in self.provider.liveStream() {
                self.lastKnownTimestamp = tick.timestamp
                await self.liveHandler(tick)
            }
        }
    }

    private func recoverMissingData(from startDate: Date, to endDate: Date) async {
        guard !isRecovering else { return }
        isRecovering = true
        defer {
            isRecovering = false
            lastKnownTimestamp = nil
        }
        do {
            let missing = try await provider.fetchKLineItems(from: startDate, to: endDate)
            if !missing.isEmpty {
                await snapshotHandler(-1, missing)
            }
        } catch {
            print("Recovery error: \(error)")
        }
        startLiveStream()
    }
}
