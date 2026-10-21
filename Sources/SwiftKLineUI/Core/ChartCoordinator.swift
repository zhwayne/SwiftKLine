//
//  ChartCoordinator.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/05/17.
//

import SwiftKLineCore
#if canImport(UIKit)
import UIKit
#endif
import Foundation

/// Owns raw chart state and one provider session on the main actor.
///
/// Loader generations reject callbacks from replaced providers. Indicator calculation returns snapshots to
/// ChartView; only the view decides when a matched candle/output snapshot is ready for publication.
@MainActor
final class ChartCoordinator {
    var state: ChartState
    var onStateUpdated: (@MainActor @Sendable (ChartState, LiveTickMergeResult?, DataLoaderEvent?) -> Void)?

    private var indicatorPipeline: IndicatorPipeline
    private var itemLoader: ChartItemLoader?
    private var dataMerger = DataMerger()
    private var networkObserver = NetworkObserver()
    private var loaderGeneration = UUID()
    private var initialPageLoaded = false
    // Keep only the latest snapshot per identity while the initial page is pending or retried.
    private var pendingInitialTicks: [Int: any ChartItem] = [:]
    private let features: ChartFeatures
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

    init(
        configuration: ChartConfiguration,
        features: ChartFeatures,
        indicatorPipeline: IndicatorPipeline
    ) {
        self.features = features
        self.indicatorPipeline = indicatorPipeline
        self.state = ChartState()
    }

    // MARK: - Data Loading

    /// Replaces the loader, resets raw data and pagination-related merge state, and preserves selection and presentation.
    func loadData(using provider: some ChartItemProvider) {
        let oldLoader = itemLoader
        let generation = UUID()
        loaderGeneration = generation
        Task { await oldLoader?.stop() }
        itemLoader = nil
        state = ChartState(
            contentStyle: state.contentStyle,
            indicatorSelection: state.indicatorSelection
        )
        dataMerger.reset(period: provider.candlePeriod)
        initialPageLoaded = false
        pendingInitialTicks.removeAll()

        itemLoader = ChartItemLoader(
            provider: provider,
            enablesLiveUpdates: features.contains(.liveUpdates),
            enablesGapRecovery: features.contains(.gapRecovery),
            eventHandler: { [weak self] event in
                guard let self, self.loaderGeneration == generation else { return }
                self.handleLoaderEvent(event)
            }
        )
        let loader = itemLoader
        Task { await loader?.start() }
        onStateUpdated?(state, nil, nil)
    }

    /// Invalidates queued callbacks synchronously, then asynchronously stops the captured loader.
    func stopDataLoading() {
        // Invalidate queued UI callbacks before asynchronously cancelling the loader’s tasks.
        loaderGeneration = UUID()
        let loader = itemLoader
        itemLoader = nil
        pendingInitialTicks.removeAll()
        Task { await loader?.stop() }
    }

    /// Stops provider loading and normalizes an application-managed candle batch before announcing a new initial page.
    func setItems(_ items: [any ChartItem], period: ChartPeriod?) {
        stopDataLoading()
        dataMerger.reset(period: period)
        state.items = dataMerger.merge(current: [], patch: items)
        state.indicatorSeriesStore = IndicatorSeriesStore()
        state.lastError = nil
        initialPageLoaded = true
        onStateUpdated?(state, nil, .page(index: 0, items: state.items))
    }

    /// Applies a complete manual snapshot through the same merge and invalidation path used by live provider ticks.
    func update(_ item: any ChartItem) {
        if itemLoader == nil { initialPageLoaded = true }
        handleLoaderEvent(.liveTick(item))
    }

    func loadMoreIfNeeded(contentOffsetX: Double, viewportWidth: Double) {
        let loader = itemLoader
        Task { await loader?.loadMoreIfNeeded(contentOffsetX: contentOffsetX, viewportWidth: viewportWidth) }
    }

    // MARK: - Indicator Selection

    func setIndicatorSelection(_ selection: IndicatorSelectionState) {
        let normalized = indicatorPipeline.setSelection(selection)
        state.indicatorSelection = normalized
        onStateUpdated?(state, nil, nil)
    }

    func resetIndicatorSelection() {
        let selection = indicatorPipeline.resetSelection()
        state.indicatorSelection = selection
        onStateUpdated?(state, nil, nil)
    }

    var indicatorSelection: IndicatorSelectionState {
        state.indicatorSelection
    }

    // MARK: - Indicator Calculation

    /// Delegates calculation with the exact previous output snapshot and earliest changed input index.
    func calculateIndicators(
        items: [any ChartItem],
        selection: IndicatorSelectionState,
        previous: IndicatorSeriesStore? = nil,
        invalidatedFrom: Int = 0
    ) async -> IndicatorSeriesStore {
        await indicatorPipeline.calculate(items: items, selection: selection, previous: previous, invalidatedFrom: invalidatedFrom)
    }

    // MARK: - Content Style

    func setContentStyle(_ style: ChartType) {
        state.contentStyle = style
        onStateUpdated?(state, nil, nil)
    }

    // MARK: - Reset

    func reset() {
        state = ChartState(
            contentStyle: state.contentStyle,
            indicatorSelection: state.indicatorSelection
        )
        dataMerger.reset()
        initialPageLoaded = false
        pendingInitialTicks.removeAll()
        onStateUpdated?(state, nil, nil)
    }

    // MARK: - Lifecycle

    /// Captures the latest raw timestamp and asks the current loader to suspend live and recovery tasks.
    func handleDidEnterBackground() {
        let latestTimestamp = state.items.last?.timestamp
        let loader = itemLoader
        Task { await loader?.didEnterBackground(latestTimestamp: latestTimestamp) }
    }

    /// Requests recovery and/or live resumption using the latest raw timestamp.
    func handleWillEnterForeground() {
        let latestTimestamp = state.items.last?.timestamp
        let loader = itemLoader
        Task { await loader?.willEnterForeground(latestTimestamp: latestTimestamp) }
    }

    func startLifecycleObservation() {
        #if canImport(UIKit)
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handleDidEnterBackground() }
        }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handleWillEnterForeground() }
        }
        #endif
    }

    func stopLifecycleObservation() {
        #if canImport(UIKit)
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
            backgroundObserver = nil
        }
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
            foregroundObserver = nil
        }
        #endif
    }

    // MARK: - Network

    func startNetworkObservation() {
        networkObserver.statusDidChange = { [weak self] status in
            guard let self else { return }
            switch status {
            case .available:
                self.handleNetworkRecovery()
            case .unavailable:
                self.handleNetworkDisconnection()
            }
        }
        networkObserver.start()
    }

    func stopNetworkObservation() {
        networkObserver.stop()
    }

    // MARK: - Private

    /// Applies loader events in main-actor order and reports the earliest affected live index to the view.
    private func handleLoaderEvent(_ event: DataLoaderEvent) {
        var liveTickResult: LiveTickMergeResult? = nil
        switch event {
        case let .page(index, items):
            if index == 0 {
                // Initial history and live consumption overlap. Normalize history before replaying buffered ticks
                // to retain new candles and prevent stale HTTP snapshots from replacing newer live values.
                state.items = dataMerger.merge(current: [], patch: items)
                for tick in pendingInitialTicks.values.sorted(by: { $0.timestamp < $1.timestamp }) {
                    _ = dataMerger.applyLiveTick(tick, to: &state.items)
                }
                pendingInitialTicks.removeAll()
                initialPageLoaded = true
            } else {
                state.items = dataMerger.merge(current: state.items, patch: items)
            }
        case let .recovery(items):
            state.items = dataMerger.merge(current: state.items, patch: items)
        case let .liveTick(tick):
            if !initialPageLoaded {
                pendingInitialTicks[tick.timestamp] = tick
            }
            liveTickResult = dataMerger.applyLiveTick(tick, to: &state.items)
        case let .failed(error):
            state.lastError = error
        }
        onStateUpdated?(state, liveTickResult, event)
    }

    private func handleNetworkRecovery() {
        guard features.contains(.gapRecovery) else { return }
        let latestTimestamp = state.items.last?.timestamp
        let loader = itemLoader
        Task { await loader?.willEnterForeground(latestTimestamp: latestTimestamp) }
    }

    private func handleNetworkDisconnection() {
        guard features.contains(.gapRecovery) else { return }
        let latestTimestamp = state.items.last?.timestamp
        let loader = itemLoader
        Task { await loader?.didEnterBackground(latestTimestamp: latestTimestamp) }
    }
}