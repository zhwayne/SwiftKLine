#if canImport(UIKit)
import UIKit
#endif
import Foundation

@MainActor
final class ChartCoordinator {
    var state: ChartState
    var onStateUpdated: (@MainActor @Sendable (ChartState, LiveTickMergeResult?, DataLoaderEvent?) -> Void)?
    var onLoadError: (@MainActor @Sendable (Error) -> Void)?

    private var indicatorPipeline: IndicatorPipeline
    private var itemLoader: ChartItemLoader?
    private var dataMerger = DataMerger()
    private var networkObserver = NetworkObserver()
    private var loaderGeneration = UUID()
    private var liveRedrawThrottle = LiveRedrawThrottle()
    private let configuration: ChartConfiguration
    private let features: ChartFeatures
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

    init(
        configuration: ChartConfiguration,
        features: ChartFeatures,
        indicatorPipeline: IndicatorPipeline
    ) {
        self.configuration = configuration
        self.features = features
        self.indicatorPipeline = indicatorPipeline
        self.state = ChartState()
    }

    // MARK: - Data Loading

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
        dataMerger.reset()
        liveRedrawThrottle.reset()

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

    func calculateIndicators(
        items: [any ChartItem],
        selection: IndicatorSelectionState
    ) async -> IndicatorSeriesStore {
        await indicatorPipeline.calculate(items: items, selection: selection)
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
        liveRedrawThrottle.reset()
        onStateUpdated?(state, nil, nil)
    }

    // MARK: - Lifecycle

    func handleDidEnterBackground() {
        guard features.contains(.gapRecovery) else { return }
        let latestTimestamp = state.items.last?.timestamp
        let loader = itemLoader
        Task { await loader?.didEnterBackground(latestTimestamp: latestTimestamp) }
    }

    func handleWillEnterForeground() {
        guard features.contains(.gapRecovery) else { return }
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
            self?.handleDidEnterBackground()
        }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWillEnterForeground()
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

    // MARK: - Live Tick Throttle

    func shouldRedraw() -> Bool {
        liveRedrawThrottle.shouldRedraw()
    }

    func resetLiveRedrawThrottle() {
        liveRedrawThrottle.reset()
    }

    // MARK: - Private

    private func handleLoaderEvent(_ event: DataLoaderEvent) {
        var liveTickResult: LiveTickMergeResult? = nil
        switch event {
        case let .page(index, items):
            if index == 0 {
                dataMerger.prepareBucketsIfNeeded(with: items)
                state.items = items
            } else {
                state.items = dataMerger.merge(current: state.items, patch: items)
            }
        case let .recovery(items):
            state.items = dataMerger.merge(current: state.items, patch: items)
        case let .liveTick(tick):
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