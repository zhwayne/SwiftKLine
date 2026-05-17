//
//  ChartView.swift
//  KLineDemo
//
//  Created by iya on 2024/10/31.
//

import UIKit
import SnapKit

enum ChartSection: Sendable {
    case mainChart, timeline, subChart
}

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
    private var chartHeightConstraint: Constraint!
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
    private nonisolated(unsafe) var scrollToTopObserver: (any NSObjectProtocol)?
    public var indicatorSelectionChanged: ((IndicatorSelectionState) -> Void)?
    public var onLoadError: ((Error) -> Void)?
    
    // MARK: - Initializers
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
        watermarkLabel.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.height.equalTo(candleHeight)
        }
        
        chartView.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.bottom.equalTo(indicatorTypeView.snp.top)
            chartHeightConstraint = make.height.equalTo(descriptor.height).constraint
        }
        indicatorTypeView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(indicatorTypeHeight)
            make.top.equalTo(chartView.snp.bottom)
        }
        
        chartView.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        legendLabel.numberOfLines = 0
        scrollView.contentView.addSubview(legendLabel)
        legendLabel.snp.makeConstraints { make in
            make.left.equalTo(12)
            make.width.equalToSuperview().multipliedBy(0.85)
            make.top.equalTo(8)
        }
        
        addInteractions()
        observeScrollViewLayoutChange()
        setupActions()
        if features.contains(.gapRecovery) {
            setupNetworkObservation()
            coordinator.startLifecycleObservation()
        }
        updateDescriptorAndDrawContent()
        scheduleDescriptorUpdate()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        descriptorUpdateTask?.cancel()
        let coordinator = coordinator
        let observer = scrollToTopObserver
        scrollToTopObserver = nil
        Task { @MainActor in
            coordinator.stopNetworkObservation()
            coordinator.stopLifecycleObservation()
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
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
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        legendCache.clear()
        scheduleRedraw(.full)
    }
    
    public override func invalidateIntrinsicContentSize() {
        chartHeightConstraint.update(offset: descriptor.height)
        layout.updateContentSize()
        super.invalidateIntrinsicContentSize()
    }
    
    public override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.width = max(size.width, bounds.width)
        size.height = viewHeight
        return size
    }
    
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        return CGSize(width: size.width, height: viewHeight)
    }
    
    private func setupActions() {
        indicatorTypeView.onAddIndicator = { [weak self] section, indicatorID in
            Task { [weak self] in
                await self?.addIndicator(indicatorID, in: section)
            }
        }
        indicatorTypeView.onRemoveIndicator = { [weak self] section, indicatorID in
            self?.removeIndicator(indicatorID, in: section)
        }
        scrollToTopObserver = NotificationCenter.default.addObserver(
            forName: .scrollToTop,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScrollToTopNotification()
        }
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
        if !persistedState.main.isEmpty || !persistedState.sub.isEmpty {
            return persistedState
        }

        guard let declaredSelection else {
            return IndicatorSelectionState(
                mainIndicators: configuration.defaultMainIndicators,
                subIndicators: configuration.defaultSubIndicators
            )
        }

        let main = deduplicatedIDs(
            declaredSelection.main,
            placement: .main,
            pluginRegistry: pluginRegistry
        )
        let sub = deduplicatedIDs(
            declaredSelection.sub,
            placement: .sub,
            pluginRegistry: pluginRegistry
        )
        return IndicatorSelectionState(main: main, sub: sub)
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
    
    public func loadData(using provider: some ChartItemProvider) {
        descriptorUpdateTask?.cancel()
        coordinator.loadData(using: provider)
        items = coordinator.state.items
        indicatorSeriesStore = coordinator.state.indicatorSeriesStore
        scheduleDescriptorUpdate()
    }
}

private extension ChartView {
    func handleCoordinatorUpdate(state: ChartState, liveTickResult: LiveTickMergeResult?, event: DataLoaderEvent?) {
        items = state.items
        indicatorSeriesStore = state.indicatorSeriesStore

        guard let event else { return }

        let tickResult = liveTickResult
        Task { [weak self] in
            guard let self else { return }
            switch event {
            case let .page(index, _):
                if index == 0 {
                    await self.draw(items: self.items, scrollPosition: .right)
                } else {
                    await self.draw(items: self.items, scrollPosition: .current)
                }
            case .recovery:
                guard self.features.contains(.gapRecovery) else { return }
                await self.draw(items: self.items, scrollPosition: .right)
            case .liveTick:
                let shouldStickToRightEdge = self.scrollView.isNearRightEdge
                await self.applyLiveTickMergeResult(
                    tickResult,
                    shouldStickToRightEdge: shouldStickToRightEdge
                )
            case let .failed(error):
                self.onLoadError?(error)
            }
        }
    }
}

// MARK: - 切换主图模式
extension ChartView {
    
    public func setContentStyle(_ style: ChartType) {
        guard mainChartContent != style else { return }
        mainChartContent = style
        coordinator.setContentStyle(style)
        scheduleDescriptorUpdate()
    }
}

// MARK: - 绘制和擦除指标
extension ChartView {
    
    private func scheduleDescriptorUpdate(recalculateValues: Bool = true) {
        descriptorUpdateTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.updateDescriptor(recalculateValues: recalculateValues)
        }
    }
    
    @MainActor
    private func updateDescriptor(recalculateValues: Bool) async {
        guard !Task.isCancelled else { return }
        
        if recalculateValues {
            let store = await calculateIndicators(
                items: items,
                selection: coordinator.state.indicatorSelection
            )
            guard !Task.isCancelled else { return }
            indicatorSeriesStore = store
            coordinator.state.indicatorSeriesStore = store
        }
        
        updateDescriptorAndDrawContent()
    }
    
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
    
    private func draw(items: [any ChartItem], scrollPosition: ChartScrollView.ScrollPosition) async {
        // 取消之前的更新任务
        descriptorUpdateTask?.cancel()
        
        let newIndicatorSeriesStore = await calculateIndicators(
            items: items,
            selection: coordinator.state.indicatorSelection
        )
        guard !Task.isCancelled else { return }
        
        coordinator.state.items = items
        coordinator.state.indicatorSeriesStore = newIndicatorSeriesStore
        self.items = coordinator.state.items
        self.indicatorSeriesStore = coordinator.state.indicatorSeriesStore
        layout.itemCount = items.count
        
        scrollView.scroll(to: scrollPosition)
        
        await updateDescriptor(recalculateValues: false)
    }
    
    private func addIndicator(_ indicatorID: IndicatorID, in section: ChartSection) async {
        guard section == .mainChart || section == .subChart else { return }
        guard !selections(in: section).contains(where: { $0 == indicatorID }) else { return }
        var state = coordinator.state.indicatorSelection
        if section == .mainChart {
            state.main.append(indicatorID)
        } else {
            state.sub.append(indicatorID)
        }
        coordinator.setIndicatorSelection(state)
        indicatorTypeView.setSelectedIndicators(coordinator.state.indicatorSelection)
        saveIndicatorSelection()
        descriptorUpdateTask?.cancel()
        await updateDescriptor(recalculateValues: true)
    }

    private func removeIndicator(_ indicatorID: IndicatorID, in section: ChartSection) {
        guard section == .mainChart || section == .subChart else { return }
        var state = coordinator.state.indicatorSelection
        let oldState = state
        if section == .mainChart {
            state.main.removeAll { $0 == indicatorID }
        } else {
            state.sub.removeAll { $0 == indicatorID }
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
            return coordinator.state.indicatorSelection.main
        case .subChart:
            return coordinator.state.indicatorSelection.sub
        case .timeline:
            return []
        }
    }
    
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
        coordinator.state.indicatorSelection.main
    }

    private var selectedSubIndicatorIDs: [IndicatorID] {
        coordinator.state.indicatorSelection.sub
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
        (coordinator.state.indicatorSelection.main, coordinator.state.indicatorSelection.sub)
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
                state.main.append(indicatorID)
            } else if section == .subChart {
                state.sub.append(indicatorID)
            }
            coordinator.setIndicatorSelection(state)
            indicatorTypeView.setSelectedIndicators(coordinator.state.indicatorSelection)
            saveIndicatorSelection()
            scheduleDescriptorUpdate()
        }
    }

    func debugDraw(items: [any ChartItem]) async {
        await draw(items: items, scrollPosition: .current)
    }

    var debugItemTimestamps: [Int] {
        items.map(\.timestamp)
    }

    var debugCoordinatorItemTimestamps: [Int] {
        coordinator.state.items.map(\.timestamp)
    }
}
#endif

// MARK: - 绘制内容
extension ChartView {
    
    private func drawVisibleContent(mode: RedrawMode = .full) {
        let drawStartTime = CACurrentMediaTime()
        var legendCost: CFTimeInterval = 0
        var boundsCost: CFTimeInterval = 0
        var rendererCost: CFTimeInterval = 0
        guard !items.isEmpty else { return }
        
        // 防御性检查：确保 layout.itemCount 与 items.count 一致
        // 虽然 draw() 方法已经保证了原子性更新，但这里保留检查作为额外保护
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
            selectedIndex: selectedIndex
        )

        let currentColorSignature = ColorAppearanceSignature(traitCollection: traitCollection)
        let crosshairLocation = selectedLocation
        let hasCrosshairRenderer = crosshairRenderer != nil
        let canUseCrosshairFastPath = hasCrosshairRenderer
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

        if hasCrosshairRenderer, let location = crosshairLocation {
            defer {
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
    func applyLiveTickMergeResult(
        _ result: LiveTickMergeResult?,
        shouldStickToRightEdge: Bool
    ) async {
        layout.itemCount = items.count
        if shouldStickToRightEdge {
            switch result {
            case let .inserted(_, appendedToTail) where appendedToTail:
                scrollView.scroll(to: .right)
            default:
                break
            }
        }
        throttleRecalculateAndRedraw()
    }
    
    func throttleRecalculateAndRedraw() {
        guard coordinator.shouldRedraw() else { return }
        scheduleDescriptorUpdate(recalculateValues: true)
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
        // 根据 location 定位当前所在的 group
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
