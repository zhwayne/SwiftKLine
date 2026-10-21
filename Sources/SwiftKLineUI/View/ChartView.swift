//
//  ChartView.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2024/10/31.
//

import SwiftKLineCore
import UIKit

/// Internal section roles used for renderer groups, indicator commands, and legend layout.
enum ChartSection: Sendable {
    case mainChart, timeline, subChart
}

/// A main-actor UIKit candlestick and time-series chart with reusable, visible-range renderers.
///
/// Use setItems/update for application-managed snapshots, or loadData for provider-managed history and live data.
/// Candle and indicator results are published together; creation-time appearance and plugin configuration are captured.
@MainActor public final class ChartView: UIView {
    
    // MARK: - Views
    private let chartView = UIView()
    private let scrollView = ChartScrollView()
    private let legendLabel = UILabel()
    private var indicatorTypeView = IndicatorTypeView()
    private let watermarkLabel = UILabel()
    private lazy var layout = ChartLayout(scrollView: scrollView, candleDimensions: candleDimensions)
    private let configuration: ChartConfiguration
    private var candleDimensions: CandleDimensions
    private var layoutMetrics: LayoutMetrics { configuration.layoutMetrics }
    
    // MARK: - Height defines
    private var candleHeight: CGFloat { layoutMetrics.mainChartHeight }
    private var timelineHeight: CGFloat { layoutMetrics.timelineHeight }
    private var indicatorHeight: CGFloat { layoutMetrics.indicatorHeight }
    private var indicatorTypeHeight: CGFloat { layoutMetrics.indicatorSelectorHeight }
    private var chartHeightConstraint: NSLayoutConstraint!
    private var viewHeight: CGFloat { descriptor.height + indicatorTypeHeight }
    
    // MARK: - ChartDescriptor
    private var descriptor = ChartDescriptor()
    private var customRenderers = [AnyRenderer]()
    private var crosshairRenderer: CrosshairRenderer?
    
    private struct ColorAppearanceSignature: Hashable {
        let userInterfaceStyle: UIUserInterfaceStyle
        let accessibilityContrast: UIAccessibilityContrast
        let displayScale: CGFloat
        
        init(traitCollection: UITraitCollection) {
            userInterfaceStyle = traitCollection.userInterfaceStyle
            accessibilityContrast = traitCollection.accessibilityContrast
            displayScale = traitCollection.displayScale
        }
    }
    private var lastFullDrawColorSignature: ColorAppearanceSignature?
    private struct LegendCacheKey: Hashable {
        let groupIndex: Int
        let currentIndex: Int
        let colorSignature: ColorAppearanceSignature
        let rendererIDsHash: Int
    }
    private var redrawScheduler = RedrawScheduler()
    private var legendCache = LegendCache<LegendCacheKey>()
    #if DEBUG
    private var debugDrawReporter = DebugDrawReporter()
    #endif
    private var mainChartContent: ChartType = .candlestick
    // Source/selection generations reject obsolete work. Live ticks coalesce into the next snapshot.
    /// Records input received while a timer or calculation is already active.
    private var pendingRefresh = false
    /// Separates structural changes from ordinary data refreshes so stable renderers are reused.
    private var descriptorNeedsRebuild = true
    /// Earliest changed raw index since the current batch started; nil means the published values remain reusable.
    private var dataInvalidatedFrom: Int? = 0
    private var pendingScrollPosition: ChartScrollView.ScrollPosition?
    private var dataRevision: UInt64 = 0
    /// Rejects calculations started for an obsolete source, selection, or presentation.
    private var renderGeneration = UUID()
    /// At most one scheduled refresh driver; replacing it cancels its predecessor before another driver starts.
    private var descriptorUpdateTask: Task<Void, Never>? {
        didSet { oldValue?.cancel() }
    }
    
    // MARK: - Data
    private let features: ChartFeatures
    private var coordinator: ChartCoordinator
    private var items: [any ChartItem] = []
    private var indicatorSeriesStore = IndicatorSeriesStore()
    private let descriptorFactory = DescriptorFactory()
    private let pluginRegistry: PluginRegistry
    private let rendererReconciler = RendererReconciler()
    private let crosshairDrawCoordinator = CrosshairDrawCoordinator()
    private let groupDrawCoordinator = GroupDrawCoordinator()
    private let legendCoordinator = LegendCoordinator()
    private let visibleContentCoordinator = VisibleContentCoordinator()
    private var selectedIndex: Int?
    private var selectedLocation: CGPoint?
    private var longPressLocation: CGPoint = .zero
    private let observations = ChartObservations()
    /// Called on the main actor after chart commands or selector actions submit a normalized, persisted selection.
    public var indicatorSelectionChanged: ((IndicatorSelectionState) -> Void)?
    /// Called on the main actor for history or recovery request errors; provider live-stream failures are provider-owned.
    public var onLoadError: ((Error) -> Void)?
    
    // MARK: - Initializers
    /// Creates a chart from an explicit visual configuration and plugin registry.
    ///
    /// - Parameters:
    ///   - frame: Initial UIKit frame.
    ///   - configuration: Creation-time appearance, layout, and built-in defaults.
    ///   - indicatorSelectionStore: Synchronous selection storage; pass nil to disable storage for this initializer.
    ///   - pluginRegistry: A registry configured before chart creation.
    ///   - initialIndicatorSelection: Declared selection, used after any nonempty saved selection.
    ///   - features: Provider lifecycle capabilities. The options initializer also uses indicatorPersistence to gate storage.
    public init(
        frame: CGRect = .zero,
        configuration: ChartConfiguration = ChartConfiguration(),
        indicatorSelectionStore: IndicatorSelectionStore? = UserDefaultsIndicatorSelectionStore(),
        pluginRegistry: PluginRegistry = .default,
        initialIndicatorSelection: IndicatorSelectionState? = nil,
        features: ChartFeatures = .all
    ) {
        self.configuration = configuration
        self.candleDimensions = CandleDimensions(width: configuration.candleStyle.width, gap: configuration.candleStyle.gap)
        self.features = features
        self.pluginRegistry = pluginRegistry
        let availableMain = configuration.indicators.filter { $0.isMain && !$0.defaultSeriesKeys.isEmpty }
        let availableSub = configuration.indicators.filter { !$0.isMain && !$0.defaultSeriesKeys.isEmpty }
        let indicatorSelectionNormalizer = IndicatorSelectionNormalizer(
            availableMain: availableMain,
            availableSub: availableSub,
            pluginRegistry: pluginRegistry
        )
        let indicatorPipeline = IndicatorPipeline(
            configuration: configuration,
            normalizer: indicatorSelectionNormalizer,
            selectionStore: indicatorSelectionStore,
            registry: pluginRegistry
        )
        coordinator = ChartCoordinator(
            configuration: configuration,
            features: features,
            indicatorPipeline: indicatorPipeline
        )
        super.init(frame: frame)
        coordinator.onStateUpdated = { [weak self] state, liveTickResult, event in
            self?.handleCoordinatorUpdate(state: state, liveTickResult: liveTickResult, event: event)
        }
        let persistedState = indicatorPipeline.initialSelection()
        let initialSelection = resolveInitialIndicatorSelection(
            initialIndicatorSelection,
            persistedState: persistedState,
            pluginRegistry: pluginRegistry
        )
        coordinator.setIndicatorSelection(initialSelection)
        chartView.layer.masksToBounds = true
        indicatorTypeView.mainIndicators = availableMain
        indicatorTypeView.subIndicators = availableSub
        indicatorTypeView.mainCustomIndicators = customIndicatorItems(for: .main, pluginRegistry: pluginRegistry)
        indicatorTypeView.subCustomIndicators = customIndicatorItems(for: .sub, pluginRegistry: pluginRegistry)
        indicatorTypeView.setSelectedIndicators(coordinator.indicatorSelection)
        
        addSubview(chartView)
        addSubview(indicatorTypeView)
        
        watermarkLabel.textAlignment = .center
        watermarkLabel.text = configuration.watermarkText
        watermarkLabel.textColor = .tertiarySystemFill
        watermarkLabel.font = .systemFont(ofSize: 32, weight: .bold)
        watermarkLabel.layer.zPosition = -1
        chartView.addSubview(watermarkLabel)
        chartView.addSubview(scrollView)
        legendLabel.numberOfLines = 0
        scrollView.contentView.addSubview(legendLabel)
        for view in [chartView, indicatorTypeView, watermarkLabel, scrollView, legendLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        chartHeightConstraint = chartView.heightAnchor.constraint(equalToConstant: descriptor.height)
        NSLayoutConstraint.activate([
            chartView.leadingAnchor.constraint(equalTo: leadingAnchor),
            chartView.trailingAnchor.constraint(equalTo: trailingAnchor),
            chartView.topAnchor.constraint(equalTo: topAnchor),
            chartView.bottomAnchor.constraint(equalTo: indicatorTypeView.topAnchor),
            chartHeightConstraint,
            indicatorTypeView.leadingAnchor.constraint(equalTo: leadingAnchor),
            indicatorTypeView.trailingAnchor.constraint(equalTo: trailingAnchor),
            indicatorTypeView.bottomAnchor.constraint(equalTo: bottomAnchor),
            indicatorTypeView.heightAnchor.constraint(equalToConstant: indicatorTypeHeight),
            watermarkLabel.leadingAnchor.constraint(equalTo: chartView.leadingAnchor),
            watermarkLabel.trailingAnchor.constraint(equalTo: chartView.trailingAnchor),
            watermarkLabel.topAnchor.constraint(equalTo: chartView.topAnchor),
            watermarkLabel.heightAnchor.constraint(equalToConstant: candleHeight),
            legendLabel.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor, constant: 12),
            legendLabel.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor, constant: 8),
            legendLabel.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor, multiplier: 0.85)
        ])
        scrollView.pinEdges(to: chartView)

        addInteractions()
        observeScrollViewLayoutChange()
        setupActions()
        if features.contains(.gapRecovery) {
            setupNetworkObservation()
        }
        if !features.intersection([.liveUpdates, .gapRecovery]).isEmpty {
            coordinator.startLifecycleObservation()
        }
        updateDescriptorAndDrawContent()
        scheduleDescriptorUpdate()
    }
    
    /// Storyboard and archive construction are unsupported; create the chart programmatically.
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        descriptorUpdateTask?.cancel()
        let coordinator = coordinator
        let observations = observations
        Task { @MainActor in
            coordinator.stopDataLoading()
            coordinator.stopNetworkObservation()
            coordinator.stopLifecycleObservation()
            observations.removeAll()
        }
    }
    
    private func addInteractions() {
        let pinchInteraction = PinchInteraction(layout: layout) { [weak self] change in
            self?.handleCandleScaleChange(change)
        }
        chartView.addInteraction(pinchInteraction)
        let crosshairInteraction = CrosshairInteraction(layout: layout) { [weak self] location, index in
            self?.updateCrosshair(location: location, itemIndex: index)
        }
        chartView.addInteraction(crosshairInteraction)
    }
    
    /// Invalidates cached legend appearance and requests a full redraw after UIKit trait changes.
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        legendCache.clear()
        scheduleRedraw(.full)
    }
    
    /// Updates descriptor-driven height and scroll content size before notifying UIKit of size changes.
    public override func invalidateIntrinsicContentSize() {
        chartHeightConstraint.constant = descriptor.height
        layout.updateContentSize()
        super.invalidateIntrinsicContentSize()
    }
    
    /// The descriptor’s total height plus the selector height, with width supplied by the containing layout.
    public override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.width = max(size.width, bounds.width)
        size.height = viewHeight
        return size
    }
    
    /// Preserves the proposed width and returns the height required by the current descriptor and selector.
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: size.width, height: viewHeight)
    }
    
    private func setupActions() {
        indicatorTypeView.onAddIndicator = { [weak self] section, indicatorID in
            self?.addIndicator(indicatorID, in: section)
        }
        indicatorTypeView.onRemoveIndicator = { [weak self] section, indicatorID in
            self?.removeIndicator(indicatorID, in: section)
        }
        observations.insert(NotificationCenter.default.addObserver(
            forName: .scrollToTop,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let source = notification.object as? UIView
            Task { @MainActor [weak self] in
                guard let self, let source, source.isDescendant(of: self.scrollView.contentView) else { return }
                self.handleScrollToTopNotification()
            }
        })
    }
    
    private func handleScrollToTopNotification() {
        scrollView.scroll(to: .right)
    }
}

extension ChartView {
    private func resolveInitialIndicatorSelection(
        _ declaredSelection: IndicatorSelectionState?,
        persistedState: IndicatorSelectionState,
        pluginRegistry: PluginRegistry
    ) -> IndicatorSelectionState {
        if !persistedState.mainIndicatorIDs.isEmpty || !persistedState.subIndicatorIDs.isEmpty {
            return persistedState
        }

        guard let declaredSelection else {
            return IndicatorSelectionState(
                mainIndicators: configuration.defaultMainIndicators,
                subIndicators: configuration.defaultSubIndicators
            )
        }

        let main = deduplicatedIDs(
            declaredSelection.mainIndicatorIDs,
            placement: .main,
            pluginRegistry: pluginRegistry
        )
        let sub = deduplicatedIDs(
            declaredSelection.subIndicatorIDs,
            placement: .sub,
            pluginRegistry: pluginRegistry
        )
        return IndicatorSelectionState(mainIndicatorIDs: main, subIndicatorIDs: sub)
    }

    private func deduplicatedIDs(
        _ ids: [IndicatorID],
        placement: IndicatorPlacement,
        pluginRegistry: PluginRegistry
    ) -> [IndicatorID] {
        var result: [IndicatorID] = []
        var seen = Set<IndicatorID>()
        for id in ids {
            guard isValidID(id, placement: placement, pluginRegistry: pluginRegistry), !seen.contains(id) else { continue }
            result.append(id)
            seen.insert(id)
        }
        return result
    }

    private func isValidID(_ id: IndicatorID, placement: IndicatorPlacement, pluginRegistry: PluginRegistry) -> Bool {
        if let builtIn = BuiltInIndicator(id: id) {
            if placement == .sub {
                return !builtIn.isMain
            } else {
                return builtIn.isMain
            }
        }
        guard let plugin = pluginRegistry.plugin(for: id) else { return false }
        return plugin.placement == placement || (plugin.placement == .overlay && placement == .main)
    }

    private func customIndicatorItems(
        for placement: IndicatorPlacement,
        pluginRegistry: PluginRegistry
    ) -> [IndicatorListItem] {
        customPlugins(for: placement, pluginRegistry: pluginRegistry)
            .filter { BuiltInIndicator(id: $0.id) == nil }
            .map { IndicatorListItem(selection: $0.id, title: $0.title) }
    }

    private func customPlugins(
        for placement: IndicatorPlacement,
        pluginRegistry: PluginRegistry
    ) -> [any IndicatorPlugin] {
        var plugins = pluginRegistry.plugins(for: placement)
        if placement == .main {
            plugins.append(contentsOf: pluginRegistry.plugins(for: .overlay))
        }
        return plugins
    }

    /// Creates a chart from assembly options.
    ///
    /// The indicatorPersistence feature gates the supplied selection store. Appearance, plugins, and initial selection
    /// are resolved during construction; content style is then applied through the same command path used by later changes.
    public convenience init(
        frame: CGRect = .zero,
        options: ChartOptions,
        indicatorSelectionStore: IndicatorSelectionStore? = UserDefaultsIndicatorSelectionStore()
    ) {
        self.init(
            frame: frame,
            configuration: options.resolvedConfiguration,
            indicatorSelectionStore: options.features.contains(.indicatorPersistence) ? indicatorSelectionStore : nil,
            pluginRegistry: options.plugins,
            initialIndicatorSelection: options.indicators,
            features: options.features
        )
        setContentStyle(options.content)
    }
    
    /// Replaces the provider session and clears prior candles, computed values, pagination, and visible content.
    ///
    /// Old requests and calculations are cancelled and generation-checked before publishing.
    /// - Parameter provider: A Sendable data source whose lifetime is retained by the loading session.
    public func loadData(using provider: some ChartItemProvider) {
        renderGeneration = UUID()
        descriptorUpdateTask?.cancel()
        pendingScrollPosition = nil
        coordinator.loadData(using: provider)
        items = coordinator.state.items
        indicatorSeriesStore = coordinator.state.indicatorSeriesStore
        layout.itemCount = 0
        clearRenderedContent()
        scheduleDescriptorUpdate()
    }
}

extension ChartView {
    /// Replaces the complete candle set and stops the provider session.
    ///
    /// Inputs are sorted and deduplicated; the last input occurrence of one identity wins. Indicators refresh asynchronously.
    /// - Parameters:
    ///   - items: Complete candle snapshots in any order.
    ///   - period: Optional fixed Unix-time bucket duration. Nil matches exact timestamps and supports calendar periods.
    public func setItems(_ items: [any ChartItem], period: ChartPeriod? = nil) {
        descriptorNeedsRebuild = descriptorNeedsRebuild || descriptorUpdateTask != nil
        renderGeneration = UUID()
        descriptorUpdateTask?.cancel()
        descriptorUpdateTask = nil
        dataInvalidatedFrom = 0
        coordinator.setItems(items, period: period)
        if items.isEmpty {
            self.items = []
            indicatorSeriesStore = IndicatorSeriesStore()
            layout.itemCount = 0
            clearRenderedContent()
        }
    }

    /// Inserts or revises one complete candle snapshot using the active bucket policy.
    ///
    /// The original data is updated immediately; rendering coalesces updates into bounded refresh batches.
    /// Use a stable candle-open timestamp when no fixed period was configured.
    public func update(_ item: any ChartItem) { coordinator.update(item) }

    /// Cancels provider work without discarding chart data; use loadData to start a new session.
    public func stopDataLoading() { coordinator.stopDataLoading() }

    /// The current normalized main and lower indicator selection.
    public var indicatorSelection: IndicatorSelectionState { coordinator.indicatorSelection }

    /// Normalizes and persists a selection, updates the selector, and schedules the corresponding calculations and renderer structure.
    public func setIndicators(_ selection: IndicatorSelectionState) {
        guard selection != coordinator.indicatorSelection else { return }
        coordinator.setIndicatorSelection(selection)
        indicatorTypeView.setSelectedIndicators(coordinator.indicatorSelection)
        saveIndicatorSelection()
        scheduleDescriptorUpdate()
    }

    /// Moves to the latest candle using the scroll view’s configured right inset.
    public func scrollToLatest() { scrollView.scroll(to: .right) }
}

private extension ChartView {
    func handleCoordinatorUpdate(state: ChartState, liveTickResult: LiveTickMergeResult?, event: DataLoaderEvent?) {
        guard let event else { return }

        switch event {
        case let .page(index, _):
            scheduleDraw(scrollPosition: index == 0 ? .right : .current)
        case .recovery:
            guard features.contains(.gapRecovery) else { return }
            scheduleDraw(scrollPosition: .right)
        case .liveTick:
            let shouldStickToRightEdge = scrollView.isNearRightEdge
            applyLiveTickMergeResult(liveTickResult, shouldStickToRightEdge: shouldStickToRightEdge)
        case let .failed(error):
            onLoadError?(error)
        }
    }
}

// MARK: - Main presentation changes
extension ChartView {
    
    /// Switches the main presentation and rebuilds renderer structure, reusing computed values when safe.
    public func setContentStyle(_ style: ChartType) {
        guard mainChartContent != style else { return }
        mainChartContent = style
        coordinator.setContentStyle(style)
        scheduleDescriptorUpdate(recalculateValues: false)
    }
}

// MARK: - Indicator calculation and renderer structure
extension ChartView {
    
    /// Invalidates older structural work and schedules a fresh descriptor pass, preserving any pending data invalidation.
    private func scheduleDescriptorUpdate(recalculateValues: Bool = true) {
        let hasPendingCalculation = descriptorUpdateTask != nil || dataInvalidatedFrom != nil
        renderGeneration = UUID()
        descriptorUpdateTask?.cancel()
        descriptorUpdateTask = nil
        descriptorNeedsRebuild = true
        if recalculateValues || hasPendingCalculation { dataInvalidatedFrom = 0 }
        pendingRefresh = true
        startScheduledRefresh()
    }

    /// Installs one refresh driver with an optional fixed delay; later live ticks do not reset its deadline.
    private func startScheduledRefresh(delay: UInt64 = 0) {
        guard descriptorUpdateTask == nil else { return }
        descriptorUpdateTask = Task(priority: .userInitiated) { [weak self] in
            if delay > 0 {
                do { try await Task.sleep(nanoseconds: delay) } catch { return }
            }
            await self?.performScheduledRefresh()
        }
    }

    /// Takes pending work before suspension and atomically publishes matching candles and indicator outputs afterward.
    ///
    /// A cancelled predecessor must not consume replacement flags. New ticks received during calculation remain queued
    /// for the next snapshot rather than invalidating an otherwise valid completed batch.
    private func performScheduledRefresh() async {
        // A cancelled task can still begin executing after its replacement was scheduled.
        // It must not consume the replacement's dirty range or pending descriptor flags.
        guard !Task.isCancelled else { return }
        let generation = renderGeneration
        let snapshot = coordinator.state.items
        let selection = coordinator.indicatorSelection
        let invalidatedFrom = dataInvalidatedFrom
        let rebuild = descriptorNeedsRebuild
        let scrollPosition = pendingScrollPosition
        pendingRefresh = false
        dataInvalidatedFrom = nil
        descriptorNeedsRebuild = false
        pendingScrollPosition = nil
        let store: IndicatorSeriesStore
        if let invalidatedFrom {
            store = await coordinator.calculateIndicators(items: snapshot, selection: selection,
                previous: indicatorSeriesStore, invalidatedFrom: invalidatedFrom)
        } else {
            store = indicatorSeriesStore
        }
        guard !Task.isCancelled, generation == renderGeneration else { return }
        // Publish candles and indicator values together, even when more ticks arrived during calculation.
        // Continuous feeds therefore cannot starve rendering, and renderers never see mismatched indexes.
        dataRevision &+= 1
        items = snapshot
        indicatorSeriesStore = store
        coordinator.state.indicatorSeriesStore = store
        layout.itemCount = snapshot.count
        if let scrollPosition { scrollView.scroll(to: scrollPosition) }
        if rebuild {
            updateDescriptorAndDrawContent()
        } else {
            legendCache.clear()
            scheduleRedraw(.full)
        }
        descriptorUpdateTask = nil
        if pendingRefresh { startScheduledRefresh(delay: 200_000_000) }
    }

    /// Uninstalls stale renderer objects and crosshair content before rebuilding an empty chart structure.
    private func clearRenderedContent() {
        descriptor.renderers.forEach { $0.uninstall(from: scrollView.contentView.canvas) }
        crosshairRenderer?.uninstall(from: scrollView.contentView.canvas)
        crosshairRenderer = nil
        selectedIndex = nil
        selectedLocation = nil
        coordinator.state.selectedIndex = nil
        coordinator.state.selectedLocation = nil
        descriptor = ChartDescriptor()
        dataRevision &+= 1
        updateDescriptorAndDrawContent()
    }

    /// Reconciles descriptor structure by renderer identity, applies layer transitions without animation, and requests a draw.
    private func updateDescriptorAndDrawContent() {
        var newDescriptor = descriptorFactory.makeDescriptor(
            contentStyle: mainChartContent,
            mainIndicatorIDs: selectedMainIndicatorIDs,
            subIndicatorIDs: selectedSubIndicatorIDs,
            customRenderers: customRenderers,
            configuration: configuration,
            layoutMetrics: layoutMetrics,
            registry: pluginRegistry
        )
        let oldDescriptor = descriptor
        let transition = rendererReconciler.reconcile(from: oldDescriptor, to: &newDescriptor)
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setAnimationDuration(0)
        defer { CATransaction.commit() }
        
        transition.removed.forEach { renderer in
            renderer.uninstall(from: scrollView.contentView.canvas)
        }
        transition.added.forEach { renderer in
            renderer.install(to: scrollView.contentView.canvas)
        }
        
        descriptor = newDescriptor
        legendCache.clear()
        invalidateIntrinsicContentSize()
        scheduleRedraw(.full)
    }
    
    /// Marks historical or recovery input for full calculation while retaining the requested scroll behavior.
    private func scheduleDraw(scrollPosition: ChartScrollView.ScrollPosition) {
        dataInvalidatedFrom = 0
        pendingScrollPosition = scrollPosition
        pendingRefresh = true
        startScheduledRefresh()
    }

    // Awaitable path used by deterministic regression tests, with the same generation guarantees.
    private func draw(items: [any ChartItem], scrollPosition: ChartScrollView.ScrollPosition) async {
        let generation = renderGeneration
        let store = await calculateIndicators(items: items, selection: coordinator.indicatorSelection)
        guard !Task.isCancelled, generation == renderGeneration else { return }
        dataRevision &+= 1
        self.items = items
        layout.itemCount = items.count
        scrollView.scroll(to: scrollPosition)
        coordinator.state.indicatorSeriesStore = store
        indicatorSeriesStore = store
        updateDescriptorAndDrawContent()
    }

    private func addIndicator(_ indicatorID: IndicatorID, in section: ChartSection) {
        guard section == .mainChart || section == .subChart else { return }
        guard !selections(in: section).contains(where: { $0 == indicatorID }) else { return }
        var state = coordinator.state.indicatorSelection
        if section == .mainChart {
            state.mainIndicatorIDs.append(indicatorID)
        } else {
            state.subIndicatorIDs.append(indicatorID)
        }
        coordinator.setIndicatorSelection(state)
        indicatorTypeView.setSelectedIndicators(coordinator.state.indicatorSelection)
        saveIndicatorSelection()
        scheduleDescriptorUpdate()
    }

    private func removeIndicator(_ indicatorID: IndicatorID, in section: ChartSection) {
        guard section == .mainChart || section == .subChart else { return }
        var state = coordinator.state.indicatorSelection
        let oldState = state
        if section == .mainChart {
            state.mainIndicatorIDs.removeAll { $0 == indicatorID }
        } else {
            state.subIndicatorIDs.removeAll { $0 == indicatorID }
        }
        guard state != oldState else { return }
        coordinator.setIndicatorSelection(state)
        indicatorTypeView.setSelectedIndicators(coordinator.state.indicatorSelection)
        saveIndicatorSelection()
        scheduleDescriptorUpdate()
    }

    private func selections(in section: ChartSection) -> [IndicatorID] {
        switch section {
        case .mainChart:
            return coordinator.state.indicatorSelection.mainIndicatorIDs
        case .subChart:
            return coordinator.state.indicatorSelection.subIndicatorIDs
        case .timeline:
            return []
        }
    }
    
    /// Restores configuration defaults through selection normalization, persists them, and refreshes the chart.
    public func resetIndicatorsToDefault() {
        coordinator.resetIndicatorSelection()
        indicatorTypeView.setSelectedIndicators(coordinator.state.indicatorSelection)
        saveIndicatorSelection()
        scheduleDescriptorUpdate()
    }
    
    private func saveIndicatorSelection() {
        indicatorSelectionChanged?(coordinator.state.indicatorSelection)
    }

    private func calculateIndicators(
        items: [any ChartItem],
        selection: IndicatorSelectionState
    ) async -> IndicatorSeriesStore {
        await coordinator.calculateIndicators(
            items: items,
            selection: selection
        )
    }

    private var selectedMainIndicatorIDs: [IndicatorID] {
        coordinator.state.indicatorSelection.mainIndicatorIDs
    }

    private var selectedSubIndicatorIDs: [IndicatorID] {
        coordinator.state.indicatorSelection.subIndicatorIDs
    }
    
    private func scheduleRedraw(_ mode: RedrawMode) {
        redrawScheduler.schedule(mode) { [weak self] redrawMode in
            self?.drawVisibleContent(mode: redrawMode)
        }
    }
}

#if DEBUG
extension ChartView {
    var debugSelectedBuiltInIndicators: (main: [BuiltInIndicator], sub: [BuiltInIndicator]) {
        (coordinator.state.mainIndicators, coordinator.state.subIndicators)
    }

    var debugSelectedIndicators: (main: [IndicatorID], sub: [IndicatorID]) {
        (coordinator.state.indicatorSelection.mainIndicatorIDs, coordinator.state.indicatorSelection.subIndicatorIDs)
    }

    var debugIndicatorTypeTitles: (main: [String], sub: [String]) {
        indicatorTypeView.debugTitles
    }

    func debugToggleIndicator(_ indicatorID: IndicatorID, in section: ChartSection) {
        if selections(in: section).contains(where: { $0 == indicatorID }) {
            removeIndicator(indicatorID, in: section)
        } else {
            var state = coordinator.state.indicatorSelection
            if section == .mainChart {
                state.mainIndicatorIDs.append(indicatorID)
            } else if section == .subChart {
                state.subIndicatorIDs.append(indicatorID)
            }
            coordinator.setIndicatorSelection(state)
            indicatorTypeView.setSelectedIndicators(coordinator.state.indicatorSelection)
            saveIndicatorSelection()
            scheduleDescriptorUpdate()
        }
    }

    func debugDraw(items: [any ChartItem]) async {
        renderGeneration = UUID()
        descriptorUpdateTask?.cancel()
        coordinator.state.items = items
        self.items = items
        await draw(items: items, scrollPosition: .current)
    }

    func debugWaitForRefresh() async {
        while let task = descriptorUpdateTask { await task.value }
    }

    var debugViewportFrame: CGRect { scrollView.contentView.convert(scrollView.contentView.bounds, to: self) }
    var debugRenderedCloses: [Double] { items.map(\.close) }
    var debugRendererIdentities: [ObjectIdentifier] { descriptor.renderers.map { ObjectIdentifier($0.base) } }

    func debugRenderForInspection() -> UIImage {
        layoutIfNeeded()
        // Offscreen test views have no display cycle to lay out a programmatic scroll.
        scrollView.setNeedsLayout()
        scrollView.layoutIfNeeded()
        drawVisibleContent(mode: .full)
        return UIGraphicsImageRenderer(bounds: bounds).image { layer.render(in: $0.cgContext) }
    }

    var debugItemTimestamps: [Int] {
        items.map(\.timestamp)
    }

    var debugIndicatorSeriesStore: IndicatorSeriesStore { indicatorSeriesStore }

    var debugCoordinatorItemTimestamps: [Int] {
        coordinator.state.items.map(\.timestamp)
    }
}
#endif

// MARK: - Visible content rendering
extension ChartView {
    
    /// Draws a coherent visible snapshot, restricting the legend-only shortcut to explicit crosshair redraws.
    private func drawVisibleContent(mode: RedrawMode = .full) {
        let drawStartTime = CACurrentMediaTime()
        var legendCost: CFTimeInterval = 0
        var boundsCost: CFTimeInterval = 0
        var rendererCost: CFTimeInterval = 0
        guard !items.isEmpty else { return }
        
        // Do not draw until layout indexes and the published candle snapshot agree.
        // Snapshot publication normally guarantees this; the guard also protects manual debug drawing.
        guard layout.itemCount == items.count else {
            return
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setAnimationDuration(0)
        defer { CATransaction.commit() }
        
        let contentRect = scrollView.contentView.bounds
        let visibleRange = layout.visibleRange
        if visibleRange.isEmpty { return }
        
        let context = ChartContext(
            indicatorSeriesStore: indicatorSeriesStore,
            items: items,
            configuration: configuration,
            candleDimensions: candleDimensions,
            visibleRange: visibleRange,
            layout: layout,
            location: selectedLocation,
            selectedIndex: selectedIndex,
            dataRevision: dataRevision
        )

        let currentColorSignature = ColorAppearanceSignature(traitCollection: traitCollection)
        let crosshairLocation = selectedLocation
        let hasCrosshairRenderer = crosshairRenderer != nil
        let canUseCrosshairFastPath = mode == .crosshairOnly && hasCrosshairRenderer
            && crosshairLocation != nil
            && lastFullDrawColorSignature == currentColorSignature

        func configureLegend(for group: RendererGroup, groupIndex: Int, groupFrame: CGRect) -> CGFloat {
            let legendKey = LegendCacheKey(
                groupIndex: groupIndex,
                currentIndex: context.currentIndex,
                colorSignature: currentColorSignature,
                rendererIDsHash: LegendCache<LegendCacheKey>.rendererIDsHash(group.renderers)
            )
            let result = legendCoordinator.configureLegend(
                for: group,
                groupFrame: groupFrame,
                legendKey: legendKey,
                legendLabel: legendLabel,
                legendCache: &legendCache,
                context: context
            )
            legendCost += result.cost
            return result.viewPortOffsetY
        }

        defer {
            if hasCrosshairRenderer, let location = crosshairLocation {
                crosshairDrawCoordinator.drawCrosshair(
                    renderer: crosshairRenderer,
                    descriptor: descriptor,
                    canvas: scrollView.contentView.canvas,
                    context: context,
                    at: location
                )
            }
        }

        if canUseCrosshairFastPath,
           let location = crosshairLocation,
           let selectedGroupIndex = descriptor.indexOfGroup(at: location),
           !descriptor.groups[selectedGroupIndex].viewPort.isEmpty {
            visibleContentCoordinator.updateCrosshairFastPath(
                descriptor: &descriptor,
                contentRect: contentRect,
                context: context,
                configureLegend: configureLegend(for:groupIndex:groupFrame:)
            )
            #if DEBUG
            debugDrawReporter.report(
                drawStartTime: drawStartTime,
                legendCost: legendCost,
                boundsCost: boundsCost,
                rendererCost: rendererCost,
                mode: mode
            )
            #endif
            return
        }

        let drawCost = visibleContentCoordinator.drawFullContent(
            descriptor: &descriptor,
            contentRect: contentRect,
            canvas: scrollView.contentView.canvas,
            context: context,
            groupDrawCoordinator: groupDrawCoordinator,
            configureLegend: configureLegend(for:groupIndex:groupFrame:)
        )
        boundsCost += drawCost.boundsCost
        rendererCost += drawCost.rendererCost

        lastFullDrawColorSignature = currentColorSignature
        #if DEBUG
        debugDrawReporter.report(
            drawStartTime: drawStartTime,
            legendCost: legendCost,
            boundsCost: boundsCost,
            rendererCost: rendererCost,
            mode: mode
        )
        #endif
    }
    
}

extension ChartView {
    
    private func observeScrollViewLayoutChange() {
        scrollView.onLayoutChanged = { [weak self] scrollView in
            guard let self else { return }
            
            if crosshairRenderer != nil {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                CATransaction.setAnimationDuration(0)
                defer { CATransaction.commit() }
                selectedIndex = nil
                selectedLocation = nil
                coordinator.state.selectedIndex = nil
                coordinator.state.selectedLocation = nil
                crosshairRenderer?.uninstall(from: self.scrollView.contentView.canvas)
                crosshairRenderer = nil
            }
            scheduleRedraw(.full)
            coordinator.loadMoreIfNeeded(
                contentOffsetX: Double(scrollView.contentOffset.x),
                viewportWidth: Double(scrollView.bounds.width)
            )
        }
    }
}

// MARK: - Live merging
private extension ChartView {
    /// Accumulates the earliest affected index and tail-follow request without cancelling a running refresh batch.
    func applyLiveTickMergeResult(
        _ result: LiveTickMergeResult?,
        shouldStickToRightEdge: Bool
    ) {
        let changedIndex: Int
        switch result {
        case let .replaced(index): changedIndex = index
        case let .inserted(index, appendedToTail):
            changedIndex = index
            if appendedToTail, shouldStickToRightEdge { pendingScrollPosition = .right }
        case nil: changedIndex = 0
        }
        dataInvalidatedFrom = min(dataInvalidatedFrom ?? changedIndex, changedIndex)
        pendingRefresh = true
        // One pending timer; incoming ticks never reset its deadline or cancel running calculators.
        startScheduledRefresh(delay: 200_000_000)
    }
}

// MARK: - Network Observation
extension ChartView {
    
    private func setupNetworkObservation() {
        coordinator.startNetworkObservation()
    }
}

extension ChartView {
    
    private func handleCandleScaleChange(_ change: CandleScaleChange) {
        candleDimensions = CandleDimensions(width: change.width, gap: change.gap)
        layout.candleDimensions = candleDimensions
    }
    
    func updateCrosshair(location: CGPoint, itemIndex: Int) {
        // Update selection in viewport coordinates for the current group.
        selectedLocation = location
        selectedIndex = itemIndex
        coordinator.state.selectedLocation = location
        coordinator.state.selectedIndex = itemIndex
        if crosshairRenderer == nil {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            CATransaction.setAnimationDuration(0)
            defer { CATransaction.commit() }
            crosshairRenderer = CrosshairRenderer(configuration: configuration)
            crosshairRenderer?.install(to: scrollView.contentView.canvas)
        }
        scheduleRedraw(.crosshairOnly)
    }
}
