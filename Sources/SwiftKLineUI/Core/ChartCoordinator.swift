//
//  ChartCoordinator.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/05/17.
//

import SwiftKLineCore
import UIKit

/// Atomically published candle and plugin-output snapshots.
struct ChartSnapshot {
    var items: [any ChartItem] = []
    var stores: [String: IndicatorSeriesStore] = [:]
    var revision: UInt64 = 0
}

/// Coordinates declarative configuration, raw candles, and matched calculation publication.
@MainActor
final class ChartCoordinator {
    private(set) var configuration: ChartConfiguration
    private(set) var snapshot = ChartSnapshot()
    let plugins = PluginCollection()
    var onSnapshot: ((ChartScrollView.ScrollPosition?) -> Void)?
    var onResources: ((Bool) -> Void)?
    var onLoadError: ((Error) -> Void)?
    var onPluginError: ((String, Error) -> Void)?
    var followsLatest: (() -> Bool)?
    private(set) var rawItems: [any ChartItem] = []
    private var merger = DataMerger()
    private var loader: ChartItemLoader?
    private var refreshTask: Task<Void, Never>?
    /// Live-only coalescing; history and configuration invalidations bypass this delay.
    private let liveUpdateDelay: UInt64
    /// Non-nil while the task is queued, then nil as soon as calculation begins.
    private var scheduledDelay: UInt64?
    /// Remembers urgent invalidation received while another batch is running.
    private var needsImmediateRefresh = false
    private var sourceGeneration: UInt64 = 0
    private var calculationGeneration: UInt64 = 0
    private var dirtyIndex: Int?
    private var pendingScroll: ChartScrollView.ScrollPosition?
    private var initialLoaded = false
    private var pendingTicks: [Int: any ChartItem] = [:]
    private var visibleRange: Range<Int> = 0..<0
    private var active = true
    private var applying = false
    private var calculationsChanged = false
    private var structureChanged = false
    private var redrawRequested = false
    private var network = NetworkObserver()

    init(configuration: ChartConfiguration, liveUpdateDelay: UInt64 = 200_000_000) {
        self.configuration = configuration
        self.liveUpdateDelay = liveUpdateDelay
        plugins.onChange = { [weak self] id, calculate, structure in
            guard let self else { return }
            if calculate {
                self.snapshot.stores.removeValue(forKey: id)
                self.calculationsChanged = true
                self.dirtyIndex = 0
            }
            self.structureChanged = self.structureChanged || structure
            self.redrawRequested = true
            if !self.applying { self.flushResources() }
        }
        plugins.onError = { [weak self] id, error in self?.onPluginError?(id, error) }
    }

    func apply(_ configuration: ChartConfiguration, initial: Bool = false) {
        let replace = initial || self.configuration.source.id != configuration.source.id
            || self.configuration.features.intersection(.candleLoading) != configuration.features.intersection(.candleLoading)
        applying = true
        // Appearance changes can require drawing even when plugin resources remain unchanged.
        redrawRequested = true
        if replace {
            stopLoader()
            plugins.removeAll()
            sourceGeneration &+= 1
            rawItems = []; pendingTicks = [:]; initialLoaded = false
            snapshot = ChartSnapshot(revision: snapshot.revision &+ 1)
            visibleRange = 0..<0
        }
        self.configuration = configuration
        let order = plugins.contexts.map(\.id)
        plugins.apply(configuration.plugins, input: input())
        structureChanged = structureChanged || order != plugins.contexts.map(\.id)
        applying = false
        flushResources()
        if replace {
            let provider = configuration.source.provider()
            merger.reset(period: provider.candlePeriod)
            let generation = sourceGeneration
            let session = ChartItemLoader(provider: provider,
                enablesLiveUpdates: configuration.features.contains(.liveUpdates),
                enablesGapRecovery: configuration.features.contains(.gapRecovery)) { [weak self] event in
                    guard let self, self.sourceGeneration == generation else { return }
                    self.receive(event)
                }
            loader = session
            Task { await session.start() }
            onSnapshot?(.right)
            network.stop()
            network = NetworkObserver()
            if configuration.features.contains(.gapRecovery) {
                network.statusDidChange = { [weak self] status in
                    guard let self, self.active else { return }
                    let loader = self.loader
                    let timestamp = self.rawItems.last?.timestamp
                    if status == .available { Task { await loader?.willEnterForeground(latestTimestamp: timestamp) } }
                }
                network.start()
            }
        }
    }

    func setVisibleRange(_ range: Range<Int>) {
        guard visibleRange != range else { return }
        visibleRange = range
        updatePlugins()
    }

    func setActive(_ value: Bool) {
        guard active != value else { return }
        active = value
        updatePlugins()
        let loader = loader
        let timestamp = rawItems.last?.timestamp
        Task {
            if value { await loader?.willEnterForeground(latestTimestamp: timestamp) }
            else { await loader?.didEnterBackground(latestTimestamp: timestamp) }
        }
    }

    func loadMore(contentOffsetX: Double, viewportWidth: Double) {
        guard active else { return }
        let loader = loader
        Task { await loader?.loadMoreIfNeeded(contentOffsetX: contentOffsetX, viewportWidth: viewportWidth) }
    }

    func shutdown() {
        plugins.onChange = nil
        plugins.onError = nil
        stopLoader()
        network.stop()
        plugins.removeAll()
        onSnapshot = nil; onResources = nil
        onLoadError = nil; onPluginError = nil
    }

    private func stopLoader() {
        sourceGeneration &+= 1; calculationGeneration &+= 1
        refreshTask?.cancel(); refreshTask = nil
        dirtyIndex = nil; pendingScroll = nil
        scheduledDelay = nil; needsImmediateRefresh = false
        let previous = loader; loader = nil
        Task { await previous?.stop() }
    }

    private func input() -> ChartPluginInput {
        let range = visibleRange.clamped(to: 0..<snapshot.items.count)
        var timeRange: Range<Date>?
        if !range.isEmpty {
            let first = configuration.source.candleInterval(snapshot.items[range.lowerBound].timestamp)
            let last = configuration.source.candleInterval(snapshot.items[range.upperBound - 1].timestamp)
            if first.lowerBound < last.upperBound { timeRange = first.lowerBound..<last.upperBound }
        }
        return ChartPluginInput(sourceID: configuration.source.id,
            candles: snapshot.items, visibleTimeRange: timeRange, revision: snapshot.revision, isActive: active)
    }

    private func updatePlugins() {
        applying = true
        if plugins.needsInputUpdates { plugins.update(input()) }
        applying = false
        flushResources()
    }

    private func flushResources() {
        if calculationsChanged {
            calculationsChanged = false
            calculationGeneration &+= 1
            refreshTask?.cancel(); refreshTask = nil
            scheduledDelay = nil
            schedule()
        }
        // Input delivery alone must not discard the host's reusable legend text and measurements.
        guard redrawRequested || structureChanged else { return }
        let structure = structureChanged
        structureChanged = false
        redrawRequested = false
        onResources?(structure)
    }

    private func receive(_ event: DataLoaderEvent) {
        switch event {
        case let .page(index, items):
            if index > 0 && items.isEmpty { return }
            rawItems = merger.merge(current: index == 0 ? [] : rawItems, patch: items)
            if index == 0 {
                for tick in pendingTicks.values.sorted(by: { $0.timestamp < $1.timestamp }) {
                    _ = merger.applyLiveTick(tick, to: &rawItems)
                }
                pendingTicks.removeAll(); initialLoaded = true
            }
            dirtyIndex = 0
            pendingScroll = index == 0 ? .right : .current
            schedule()
        case let .recovery(items):
            guard !items.isEmpty else { return }
            rawItems = merger.merge(current: rawItems, patch: items)
            dirtyIndex = 0
            schedule()
        case let .liveTick(item):
            if !initialLoaded { pendingTicks[item.timestamp] = item }
            let result = merger.applyLiveTick(item, to: &rawItems)
            let index: Int
            switch result {
            case let .replaced(value): index = value
            case let .inserted(value, appended):
                index = value
                if appended, followsLatest?() == true { pendingScroll = .right }
            }
            dirtyIndex = min(dirtyIndex ?? index, index)
            schedule(delay: liveUpdateDelay)
        case let .failed(error): onLoadError?(error)
        }
    }

    private func schedule(delay: UInt64 = 0) {
        guard dirtyIndex != nil else { return }
        if delay == 0 { needsImmediateRefresh = true }
        // History and configuration work must not wait behind a timer intended for live ticks.
        if needsImmediateRefresh, let scheduledDelay, scheduledDelay > 0 {
            refreshTask?.cancel(); refreshTask = nil
            self.scheduledDelay = nil
        }
        guard refreshTask == nil else { return }
        let pause = needsImmediateRefresh ? 0 : delay
        scheduledDelay = pause
        refreshTask = Task(priority: .userInitiated) { [weak self] in
            if pause > 0 { do { try await Task.sleep(nanoseconds: pause) } catch { return } }
            await self?.refresh()
        }
    }

    /// One finite batch publishes even while newer ticks wait for the next batch.
    private func refresh() async {
        guard !Task.isCancelled else { return }
        scheduledDelay = nil; needsImmediateRefresh = false
        let generation = calculationGeneration
        let items = rawItems
        let index = dirtyIndex ?? 0
        let position = pendingScroll
        dirtyIndex = nil; pendingScroll = nil
        let jobs = plugins.contexts.map { ($0.id, $0.calculators.map(\.1), snapshot.stores[$0.id]) }
        let stores = await withTaskGroup(of: (String, IndicatorSeriesStore).self) { group in
            for (id, calculators, previous) in jobs {
                group.addTask {
                    let values = await IndicatorEngine.calculate(items: items, calculators: calculators,
                        previous: previous, invalidatedFrom: index)
                    return (id, values)
                }
            }
            var outputs: [String: IndicatorSeriesStore] = [:]
            for await (id, store) in group { outputs[id] = store }
            return outputs
        }
        guard !Task.isCancelled, generation == calculationGeneration else { return }
        snapshot = ChartSnapshot(items: items, stores: stores, revision: snapshot.revision &+ 1)
        refreshTask = nil
        updatePlugins()
        onSnapshot?(position)
        schedule(delay: liveUpdateDelay)
    }

    func waitForRefresh() async {
        while let task = refreshTask { await task.value }
    }
}
