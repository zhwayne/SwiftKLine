//
//  ChartView.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2024/10/31.
//

import SwiftKLineCore
import UIKit

/// Internal section roles; plugin sub panels remain independently grouped.
enum ChartSection: Sendable { case mainChart, timeline, subChart }

/// A UIKit drawing host driven by one declarative configuration.
@MainActor
public final class ChartView: UIView {
    private let chartView = UIView()
    private var chartHeightConstraint: NSLayoutConstraint!
    private var watermarkHeightConstraint: NSLayoutConstraint!
    private let selectionController: ChartSelectionController
    private var declaredConfiguration: ChartConfiguration
    private let scrollView = ChartScrollView()
    private let legendLabel = UILabel()
    private let watermarkLabel = UILabel()
    private var candleDimensions: CandleDimensions
    private lazy var layout = ChartLayout(scrollView: scrollView, candleDimensions: candleDimensions)
    private let coordinator: ChartCoordinator
    private var descriptor = ChartDescriptor()
    private var lastPublishedCount = 0
    private let descriptorFactory = DescriptorFactory()
    private let rendererReconciler = RendererReconciler()
    private let crosshairDrawCoordinator = CrosshairDrawCoordinator()
    private let groupDrawCoordinator = GroupDrawCoordinator()
    private let legendCoordinator = LegendCoordinator()
    private let visibleContentCoordinator = VisibleContentCoordinator()
    private let observations = ChartObservations()
    private var crosshairRenderer: CrosshairRenderer?
    private var selectedIndex: Int?
    private var selectedLocation: CGPoint?
    private var redrawScheduler = RedrawScheduler()
    private var legendCache = LegendCache<LegendCacheKey>()
    private var configuration: ChartAppearance { coordinator.configuration.appearance }
    private var items: [any ChartItem] { coordinator.snapshot.items }
    private var indicatorSeriesStore: IndicatorSeriesStore { IndicatorSeriesStore() }
    private var dataRevision: UInt64 { coordinator.snapshot.revision }
    /// Called on the main actor for candle history and recovery errors.
    public var onLoadError: ((Error) -> Void)?
    /// Called on the main actor with the failed plugin ID; other features keep running.
    public var onPluginError: ((String, Error) -> Void)?

    /// Reports selection changes after they are normalized and stored when a state store is configured.
    public var selectionChanged: ((ChartSelection) -> Void)?
    /// The resolved period and indicator choices currently applied to the chart.
    public var selection: ChartSelection { selectionController.selection }

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
    private struct LegendCacheKey: Hashable {
        let groupIndex: Int
        let currentIndex: Int
        let colorSignature: ColorAppearanceSignature
        let rendererIDsHash: Int
    }
    private var lastFullDrawColorSignature: ColorAppearanceSignature?
    #if DEBUG
    private var debugDrawReporter = DebugDrawReporter()
    #endif

    /// Creates a chart with a manually supplied source. Use the factory initializer for automatic period changes.
    public convenience init(frame: CGRect = .zero, configuration: ChartConfiguration,
                selection: ChartSelection? = nil,
                stateStore: (any ChartStateStore)? = nil,
                onLoadError: ((Error) -> Void)? = nil, onPluginError: ((String, Error) -> Void)? = nil) {
        self.init(frame: frame,
                  selection: selection ?? ChartSelection(period: .oneMinute,
                    indicators: ChartSelectionController.defaults(for: configuration.appearance)),
                  stateStore: stateStore, configuration: { _ in configuration },
                  onLoadError: onLoadError, onPluginError: onPluginError)
    }

    /// Restores and normalizes selection before constructing configuration and starting provider sessions.
    /// An empty availablePeriods list accepts valid custom periods. Keep the configuration factory free of side effects.
    public init(frame: CGRect = .zero, selection: ChartSelection,
                availablePeriods: [ChartPeriod] = [], stateStore: (any ChartStateStore)? = nil,
                configuration makeConfiguration: @escaping (ChartSelection) -> ChartConfiguration,
                onLoadError: ((Error) -> Void)? = nil, onPluginError: ((String, Error) -> Void)? = nil) {
        let controller = ChartSelectionController(selection: selection, availablePeriods: availablePeriods,
            stateStore: stateStore, configuration: makeConfiguration)
        selectionController = controller
        let configuration = controller.configuration
        declaredConfiguration = configuration
        let effectiveConfiguration = controller.configuredChart()
        coordinator = ChartCoordinator(configuration: effectiveConfiguration)
        candleDimensions = CandleDimensions(width: configuration.appearance.candleStyle.width,
                                            gap: configuration.appearance.candleStyle.gap)
        super.init(frame: frame)
        self.onLoadError = onLoadError; self.onPluginError = onPluginError
        chartView.layer.masksToBounds = true
        addSubview(chartView)
        watermarkLabel.textAlignment = .center
        watermarkLabel.textColor = .tertiarySystemFill
        watermarkLabel.font = .systemFont(ofSize: 32, weight: .bold)
        watermarkLabel.layer.zPosition = -1
        chartView.addSubview(watermarkLabel)
        chartView.addSubview(scrollView)
        legendLabel.numberOfLines = 0
        scrollView.contentView.addSubview(legendLabel)
        for view in [chartView, watermarkLabel, scrollView, legendLabel] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        chartHeightConstraint = chartView.heightAnchor.constraint(equalToConstant: descriptor.height)
        watermarkHeightConstraint = watermarkLabel.heightAnchor.constraint(equalToConstant: configuration.appearance.layoutMetrics.mainChartHeight)
        NSLayoutConstraint.activate([
            chartView.leadingAnchor.constraint(equalTo: leadingAnchor),
            chartView.trailingAnchor.constraint(equalTo: trailingAnchor),
            chartView.topAnchor.constraint(equalTo: topAnchor),
            chartView.bottomAnchor.constraint(equalTo: bottomAnchor),
            chartHeightConstraint,
            watermarkLabel.leadingAnchor.constraint(equalTo: chartView.leadingAnchor),
            watermarkLabel.trailingAnchor.constraint(equalTo: chartView.trailingAnchor),
            watermarkLabel.topAnchor.constraint(equalTo: chartView.topAnchor),
            watermarkHeightConstraint,
            legendLabel.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor, constant: 12),
            legendLabel.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor, constant: 8),
            legendLabel.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor, multiplier: 0.85)
        ])
        scrollView.pinEdges(to: chartView)
        coordinator.onSnapshot = { [weak self] position in
            guard let self else { return }
            self.layout.itemCount = self.items.count
            if self.items.isEmpty, self.lastPublishedCount > 0 { self.clearRenderers(); self.rebuildDescriptor() }
            self.lastPublishedCount = self.items.count
            if let position { self.scrollView.scroll(to: position) }
            self.legendCache.clear()
            self.scheduleRedraw(.full)
        }
        coordinator.onResources = { [weak self] structure in
            guard let self else { return }
            if structure { self.rebuildDescriptor() }
            self.legendCache.clear(); self.scheduleRedraw(.full)
        }
        coordinator.onLoadError = { [weak self] in self?.onLoadError?($0) }
        coordinator.onPluginError = { [weak self] in self?.onPluginError?($0, $1) }
        coordinator.followsLatest = { [weak self] in self?.scrollView.isNearRightEdge ?? true }
        chartView.addInteraction(PinchInteraction(layout: layout) { [weak self] change in
            guard let self else { return }
            self.candleDimensions = CandleDimensions(width: change.width, gap: change.gap)
            self.layout.candleDimensions = self.candleDimensions
        })
        chartView.addInteraction(CrosshairInteraction(layout: layout) { [weak self] location, index in
            self?.updateCrosshair(location: location, itemIndex: index)
        })
        scrollView.onLayoutChanged = { [weak self] _ in
            guard let self else { return }
            self.clearCrosshair()
            self.coordinator.setVisibleRange(self.layout.visibleRange)
            self.coordinator.loadMore(contentOffsetX: Double(self.scrollView.contentOffset.x),
                                      viewportWidth: Double(self.scrollView.bounds.width))
            self.scheduleRedraw(.full)
        }
        for name in [UIScene.didActivateNotification, UIScene.willDeactivateNotification,
                     UIApplication.didEnterBackgroundNotification, UIApplication.didBecomeActiveNotification] {
            observations.insert(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let sceneID = (note.object as? UIScene).map(ObjectIdentifier.init)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let sceneID, self.window?.windowScene.map(ObjectIdentifier.init) != sceneID { return }
                    if name == UIScene.willDeactivateNotification || name == UIApplication.didEnterBackgroundNotification {
                        self.coordinator.setActive(false)
                    } else { self.updateActivity() }
                }
            })
        }
        observations.insert(NotificationCenter.default.addObserver(forName: .scrollToTop, object: nil, queue: .main) { [weak self] note in
            let source = note.object as? UIView
            Task { @MainActor [weak self] in
                guard let self, let source, source.isDescendant(of: self.scrollView.contentView) else { return }
                self.scrollToLatest()
            }
        })
        watermarkLabel.text = configuration.appearance.watermarkText
        coordinator.apply(effectiveConfiguration, initial: true)
        rebuildDescriptor()
    }

    /// Storyboard construction is unsupported; use a validated configuration.
    public required init?(coder: NSCoder) { fatalError("Create ChartView with a configuration.") }

    deinit {
        let coordinator = coordinator
        let observations = observations
        Task { @MainActor in coordinator.shutdown(); observations.removeAll() }
    }

    /// Reconciles source and plugin identities, preserving unchanged coordinators and subscriptions.
    public func apply(_ configuration: ChartConfiguration) {
        apply(configuration: { _ in configuration })
    }

    /// Updates declarations and optionally issues one complete selection command in the same transaction.
    /// Omitting selection preserves the current choices, subject to the new availability constraints.
    public func apply(selection: ChartSelection? = nil, availablePeriods: [ChartPeriod] = [],
                      configuration: @escaping (ChartSelection) -> ChartConfiguration) {
        let old = declaredConfiguration
        let oldSelection = selectionController.selection
        selectionController.apply(selection, availablePeriods: availablePeriods, configuration: configuration)
        reconcileConfiguration(previous: old, previousSelection: oldSelection)
    }

    private func reconcileConfiguration(previous old: ChartConfiguration, previousSelection oldSelection: ChartSelection) {
        let configuration = selectionController.configuration
        declaredConfiguration = configuration
        let sourceChanged = old.source.id != configuration.source.id
            || old.features.intersection(.candleLoading) != configuration.features.intersection(.candleLoading)
        let dimensionsChanged = old.appearance.candleStyle.width != configuration.appearance.candleStyle.width
            || old.appearance.candleStyle.gap != configuration.appearance.candleStyle.gap
        let geometryChanged = old.content != configuration.content
            || old.appearance.layoutMetrics != configuration.appearance.layoutMetrics || dimensionsChanged
        if sourceChanged { clearRenderers(); lastPublishedCount = 0 }
        if dimensionsChanged {
            candleDimensions = CandleDimensions(width: configuration.appearance.candleStyle.width,
                                                gap: configuration.appearance.candleStyle.gap)
            layout.candleDimensions = candleDimensions
        }
        if geometryChanged { clearCrosshair() }
        coordinator.apply(selectionController.configuredChart())
        if watermarkLabel.text != configuration.appearance.watermarkText {
            watermarkLabel.text = configuration.appearance.watermarkText
        }
        if geometryChanged { rebuildDescriptor() }
        if oldSelection != selectionController.selection {
            selectionChanged?(selectionController.selection)
        }
    }

    /// The configured panels determine height; the container determines width.
    public override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.width = max(size.width, bounds.width)
        size.height = descriptor.height
        return size
    }
    /// Preserves the original chart-height and logical scroll-size invalidation.
    public override func invalidateIntrinsicContentSize() {
        chartHeightConstraint?.constant = descriptor.height
        layout.updateContentSize()
        super.invalidateIntrinsicContentSize()
    }
    /// Returns the descriptor height while preserving the proposed width.
    public override func sizeThatFits(_ size: CGSize) -> CGSize { CGSize(width: size.width, height: descriptor.height) }
    public override func layoutSubviews() {
        super.layoutSubviews()
        coordinator.setVisibleRange(layout.visibleRange)
        scheduleRedraw(.full)
    }
    public override func didMoveToWindow() { super.didMoveToWindow(); updateActivity() }
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        legendCache.clear(); scheduleRedraw(.full)
    }

    /// Moves to the latest candle using the configured scroll insets.
    public func scrollToLatest() { scrollView.scroll(to: .right) }
    package func shutdown() { coordinator.shutdown() }

    /// Normalizes, applies and stores a complete period/indicator selection as one transaction.
    public func setSelection(_ selection: ChartSelection) {
        let old = declaredConfiguration
        let oldSelection = self.selection
        selectionController.set(selection)
        reconcileConfiguration(previous: old, previousSelection: oldSelection)
    }

    /// Restores the initial period and the current appearance's default indicators.
    public func resetSelectionToDefault() {
        let old = declaredConfiguration
        let oldSelection = selection
        selectionController.reset()
        reconcileConfiguration(previous: old, previousSelection: oldSelection)
    }

    private func updateActivity() {
        let active = window.map { $0.windowScene?.activationState == .foregroundActive
            || ($0.windowScene == nil && UIApplication.shared.applicationState != .background) } ?? false
        coordinator.setActive(active)
    }
    private func clearCrosshair() {
        crosshairRenderer?.uninstall(from: scrollView.contentView.canvas)
        crosshairRenderer = nil; selectedIndex = nil; selectedLocation = nil
    }
    private func clearRenderers() {
        descriptor.renderers.forEach { $0.uninstall(from: scrollView.contentView.canvas) }
        descriptor = ChartDescriptor()
        clearCrosshair()
    }
    private func rebuildDescriptor() {
        var next = descriptorFactory.makeDescriptor(content: coordinator.configuration.content,
            appearance: configuration, contexts: coordinator.plugins.contexts)
        let transition = rendererReconciler.reconcile(from: descriptor, to: &next)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        transition.removed.forEach { $0.uninstall(from: scrollView.contentView.canvas) }
        transition.added.forEach { $0.install(to: scrollView.contentView.canvas) }
        CATransaction.commit()
        descriptor = next
        chartHeightConstraint.constant = descriptor.height
        watermarkHeightConstraint.constant = configuration.layoutMetrics.mainChartHeight
        legendCache.clear()
        invalidateIntrinsicContentSize()
        scheduleRedraw(.full)
    }
    private func scheduleRedraw(_ mode: RedrawMode) {
        redrawScheduler.schedule(mode) { [weak self] in self?.drawVisibleContent(mode: $0) }
    }
    private func updateCrosshair(location: CGPoint, itemIndex: Int) {
        selectedLocation = location; selectedIndex = itemIndex
        if crosshairRenderer == nil {
            crosshairRenderer = CrosshairRenderer(configuration: configuration)
            crosshairRenderer?.install(to: scrollView.contentView.canvas)
        }
        scheduleRedraw(.crosshairOnly)
    }
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
            appearance: configuration,
            candleDimensions: candleDimensions,
            visibleRange: visibleRange,
            layout: layout,
            location: selectedLocation,
            selectedIndex: selectedIndex,
            dataRevision: dataRevision,
            pluginStores: coordinator.snapshot.stores,
            candleInterval: coordinator.configuration.source.candleInterval
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

#if DEBUG
extension ChartView {
    var debugVisiblePluginIDs: Set<String> {
        Set(descriptor.renderers.compactMap { ($0.base as? PluginRenderer)?.id.plugin })
    }
    var debugSelectedCandleIndex: Int? { selectedIndex }
    func debugInspectCandle(at index: Int) { updateCrosshair(location: CGPoint(x: 20, y: 80), itemIndex: index) }
    func debugWaitForRefresh() async { await coordinator.waitForRefresh() }
    var debugDataRevision: UInt64 { dataRevision }
    var debugRenderedCloses: [Double] { items.map(\.close) }
    var debugItemTimestamps: [Int] { items.map(\.timestamp) }
    var debugCoordinatorItemTimestamps: [Int] { coordinator.rawItems.map(\.timestamp) }
    var debugRendererIdentities: [ObjectIdentifier] { descriptor.renderers.map { ObjectIdentifier($0.base) } }
    var debugViewportFrame: CGRect { scrollView.contentView.convert(scrollView.contentView.bounds, to: self) }
    func debugRenderer<R: ChartRenderer>(for plugin: String, as type: R.Type) -> R? {
        coordinator.plugins.contexts.first { $0.id == plugin }?.renderers.compactMap { $0.2 as? R }.first
    }
    func debugStore(for plugin: String) -> IndicatorSeriesStore { coordinator.snapshot.stores[plugin] ?? IndicatorSeriesStore() }
    func debugRenderForInspection() -> UIImage {
        layoutIfNeeded(); scrollView.setNeedsLayout(); scrollView.layoutIfNeeded()
        drawVisibleContent(mode: .full)
        return UIGraphicsImageRenderer(bounds: bounds).image { layer.render(in: $0.cgContext) }
    }
}
#endif
