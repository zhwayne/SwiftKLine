//
//  KLineView.swift
//  KLineDemo
//
//  Created by iya on 2024/10/31.
//

import UIKit
import SnapKit
import Combine

enum ChartSection: Sendable {
    case mainChart, timeline, subChart
}

@MainActor public final class KLineView: UIView {
    
    // MARK: - Views
    private let chartView = UIView()
    private let scrollView = ChartScrollView()
    private let legendLabel = UILabel()
    private var indicatorTypeView = IndicatorTypeView()
    private let watermarkLabel = UILabel()
    private lazy var layout = KLineLayout(scrollView: scrollView, configuration: klineConfig)
    private let klineConfig: KLineConfiguration
    private var layoutMetrics: LayoutMetrics { klineConfig.layoutMetrics }
    
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
    private var controller = ChartController()
    private var klineItems: [any KLineItem] = []
    private var indicatorSeriesStore = IndicatorSeriesStore()
    private let renderPipeline: RenderPipeline
    private let rendererReconciler = RendererReconciler()
    private let crosshairDrawCoordinator = CrosshairDrawCoordinator()
    private let groupDrawCoordinator = GroupDrawCoordinator()
    private let legendCoordinator = LegendCoordinator()
    private let visibleContentCoordinator = VisibleContentCoordinator()
    private var selectedIndex: Int?
    private var selectedLocation: CGPoint?
    private var longPressLocation: CGPoint = .zero
    public var indicatorSelectionDidChange: ((IndicatorSelectionState) -> Void)?
    public var onLoadError: ((Error) -> Void)?
    
    private var disposeBag = Set<AnyCancellable>()
    private var liveRedrawThrottle = LiveRedrawThrottle()
    private var klineItemLoader: KLineItemLoader?
    private var loaderGeneration = UUID()
    private let networkObserver = NetworkObserver()
    
    // MARK: - Initializers
    public init(
        frame: CGRect = .zero,
        configuration: KLineConfiguration = KLineConfiguration(),
        indicatorSelectionStore: IndicatorSelectionStore? = UserDefaultsIndicatorSelectionStore(),
        pluginRegistry: PluginRegistry = .default,
        initialIndicatorSelection: IndicatorSelectionConfiguration? = nil,
        features: ChartFeatures = .all
    ) {
        self.klineConfig = configuration
        self.features = features
        self.renderPipeline = RenderPipeline(registry: pluginRegistry)
        let availableMain = configuration.indicators.filter { $0.isMain && !$0.defaultKeys.isEmpty }
        let availableSub = configuration.indicators.filter { !$0.isMain && !$0.defaultKeys.isEmpty }
        let indicatorSelectionNormalizer = IndicatorSelectionNormalizer(
            availableMain: availableMain,
            availableSub: availableSub,
            pluginRegistry: pluginRegistry
        )
        super.init(frame: frame)
        let indicatorPipeline = IndicatorPipeline(
            configuration: configuration,
            normalizer: indicatorSelectionNormalizer,
            selectionStore: indicatorSelectionStore,
            registry: pluginRegistry
        )
        controller = ChartController(
            indicatorPipeline: indicatorPipeline
        )
        chartView.layer.masksToBounds = true
        indicatorTypeView.mainIndicators = availableMain
        indicatorTypeView.subIndicators = availableSub
        let persistedState = indicatorPipeline.initialSelection()
        let initialSelection = resolveInitialIndicatorSelection(
            initialIndicatorSelection,
            persistedState: persistedState,
            pluginRegistry: pluginRegistry
        )
        controller.setIndicatorSelection(initialSelection)
        indicatorTypeView.mainCustomIndicators = customIndicatorItems(for: .main, pluginRegistry: pluginRegistry)
        indicatorTypeView.subCustomIndicators = customIndicatorItems(for: .sub, pluginRegistry: pluginRegistry)
        indicatorTypeView.setSelectedIndicators(controller.state.indicatorSelection)
        
        addSubview(chartView)
        addSubview(indicatorTypeView)
        
        watermarkLabel.textAlignment = .center
        watermarkLabel.text = klineConfig.watermarkText
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
        setupBindings()
        if features.contains(.gapRecovery) {
            setupNetworkObservation()
        }
        updateDescriptorAndDrawContent()
        scheduleDescriptorUpdate()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        descriptorUpdateTask?.cancel()
        let loader = klineItemLoader
        Task { await loader?.stop() }
        let observer = networkObserver
        Task { @MainActor in observer.stop() }
    }
    
    private func addInteractions() {
        let pinchInteraction = PinchInteraction(layout: layout, configuration: klineConfig)
        chartView.addInteraction(pinchInteraction)
        let crosshairInteraction = CrosshairInteraction(layout: layout, delegate: self, configuration: klineConfig)
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
    
    private func setupBindings() {
        indicatorTypeView.drawIndicatorPublisher
            .sink { [unowned self] section, selection in
                Task(priority: .userInitiated) {
                    await drawIndicator(selection, in: section)
                }
            }
            .store(in: &disposeBag)
        
        indicatorTypeView.eraseIndicatorPublisher
            .sink { [unowned self] section, selection in
                eraseIndicator(selection, in: section)
            }
            .store(in: &disposeBag)
        
        NotificationCenter.default.publisher(for: .scrollToTop)
            .sink { [weak self] _ in
                self?.scrollView.scroll(to: .right)
            }
            .store(in: &disposeBag)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleDidEnterBackground()
            }
            .store(in: &disposeBag)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleWillEnterForeground()
            }
            .store(in: &disposeBag)
    }
}

extension KLineView {
    private func resolveInitialIndicatorSelection(
        _ declaredSelection: IndicatorSelectionConfiguration?,
        persistedState: IndicatorSelectionState,
        pluginRegistry: PluginRegistry
    ) -> IndicatorSelectionState {
        if !persistedState.main.isEmpty || !persistedState.sub.isEmpty {
            return persistedState
        }

        guard let declaredSelection else {
            return IndicatorSelectionState(
                mainIndicators: klineConfig.defaultMainIndicators,
                subIndicators: klineConfig.defaultSubIndicators
            )
        }

        let main = resolveSelections(
            declaredSelection.main,
            placement: .main,
            pluginRegistry: pluginRegistry
        )
        let sub = resolveSelections(
            declaredSelection.sub,
            placement: .sub,
            pluginRegistry: pluginRegistry
        )
        return IndicatorSelectionState(main: main, sub: sub)
    }

    private func resolveSelections(
        _ selections: [IndicatorSelection],
        placement: IndicatorPlacement,
        pluginRegistry: PluginRegistry
    ) -> [IndicatorSelection] {
        var result: [IndicatorSelection] = []
        var seen = Set<IndicatorID>()
        for selection in selections {
            switch selection {
            case let .builtIn(indicator):
                guard indicator.isMain == (placement != .sub) else { continue }
            case let .custom(customID):
                guard let plugin = pluginRegistry.plugin(for: customID),
                      plugin.placement == placement || (plugin.placement == .overlay && placement == .main)
                else { continue }
            }
            guard !seen.contains(selection.id) else { continue }
            result.append(selection)
            seen.insert(selection.id)
        }
        return result
    }

    private func customIndicatorItems(
        for placement: IndicatorPlacement,
        pluginRegistry: PluginRegistry
    ) -> [KLineIndicatorListItem] {
        customPlugins(for: placement, pluginRegistry: pluginRegistry)
            .filter { KLineIndicator(kLineID: $0.id) == nil }
            .map { KLineIndicatorListItem(selection: .custom($0.id), title: $0.title) }
    }

    private func customPlugins(
        for placement: IndicatorPlacement,
        pluginRegistry: PluginRegistry
    ) -> [any KLineIndicatorPlugin] {
        var plugins = pluginRegistry.plugins(for: placement)
        if placement == .main {
            plugins.append(contentsOf: pluginRegistry.plugins(for: .overlay))
        }
        return plugins
    }

    public convenience init(
        frame: CGRect = .zero,
        chart: ChartConfiguration,
        indicatorSelectionStore: IndicatorSelectionStore? = UserDefaultsIndicatorSelectionStore()
    ) {
        self.init(
            frame: frame,
            configuration: chart.resolvedConfiguration,
            indicatorSelectionStore: chart.features.contains(.indicatorPersistence) ? indicatorSelectionStore : nil,
            pluginRegistry: chart.plugins,
            initialIndicatorSelection: chart.indicators,
            features: chart.features
        )
        setChartContentStyle(chart.content)
        if case let .provider(provider) = chart.data {
            loadData(using: provider)
        }
    }
    
    public func loadData(using provider: some KLineItemProvider) {
        descriptorUpdateTask?.cancel()
        let oldLoader = klineItemLoader
        Task { await oldLoader?.stop() }
        klineItemLoader = nil
        klineItems = []
        indicatorSeriesStore = IndicatorSeriesStore()
        controller.reset()
        liveRedrawThrottle.reset()
        let generation = UUID()
        loaderGeneration = generation
        
        klineItemLoader = KLineItemLoader(
            provider: provider,
            enablesLiveUpdates: features.contains(.liveUpdates),
            enablesGapRecovery: features.contains(.gapRecovery),
            eventHandler: { [weak self] event in
                guard let self, self.loaderGeneration == generation else { return }
                self.handleLoaderEvent(event)
            }
        )
        let loader = klineItemLoader
        Task { await loader?.start() }
    }
}

private extension KLineView {
    func handleDidEnterBackground() {
        guard features.contains(.gapRecovery) else { return }
        let latestTimestamp = klineItems.last?.timestamp
        let loader = klineItemLoader
        Task { await loader?.didEnterBackground(latestTimestamp: latestTimestamp) }
    }
    
    func handleWillEnterForeground() {
        guard features.contains(.gapRecovery) else { return }
        let latestTimestamp = klineItems.last?.timestamp
        let loader = klineItemLoader
        Task { await loader?.willEnterForeground(latestTimestamp: latestTimestamp) }
    }

    func handleLoaderEvent(_ event: DataLoaderEvent) {
        Task { [weak self] in
            guard let self else { return }
            let shouldStickToRightEdge = self.scrollView.isNearRightEdge
            let liveTickMergeResult = controller.applyLoaderEvent(event)
            synchronizeLegacyFieldsFromController()
            switch event {
            case let .page(index, _):
                if index == 0 {
                    await self.draw(items: self.klineItems, scrollPosition: .right)
                } else {
                    await self.draw(items: self.klineItems, scrollPosition: .current)
                }
            case .recovery:
                guard self.features.contains(.gapRecovery) else { return }
                await self.draw(items: self.klineItems, scrollPosition: .right)
            case .liveTick:
                await self.applyLiveTickMergeResult(
                    liveTickMergeResult,
                    shouldStickToRightEdge: shouldStickToRightEdge
                )
            case let .failed(error):
                onLoadError?(error)
            }
        }
    }

    func synchronizeLegacyFieldsFromController() {
        klineItems = controller.state.items
        indicatorSeriesStore = controller.state.indicatorSeriesStore
    }
}

// MARK: - 切换主图模式
extension KLineView {
    
    public func setChartContentStyle(_ style: ChartType) {
        guard mainChartContent != style else { return }
        mainChartContent = style
        controller.setChartContentStyle(style)
        scheduleDescriptorUpdate()
    }
}

// MARK: - 绘制和擦除指标
extension KLineView {
    
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
                items: klineItems,
                selection: controller.state.indicatorSelection
            )
            guard !Task.isCancelled else { return }
            indicatorSeriesStore = store
            controller.state.indicatorSeriesStore = store
        }
        
        updateDescriptorAndDrawContent()
    }
    
    private func updateDescriptorAndDrawContent() {
        var newDescriptor = renderPipeline.makeDescriptor(
            contentStyle: mainChartContent,
            mainIndicatorIDs: selectedMainIndicatorIDs,
            subIndicatorIDs: selectedSubIndicatorIDs,
            customRenderers: customRenderers,
            configuration: klineConfig,
            layoutMetrics: layoutMetrics
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
    
    private func draw(items: [any KLineItem], scrollPosition: ChartScrollView.ScrollPosition) async {
        // 取消之前的更新任务
        descriptorUpdateTask?.cancel()
        
        let newIndicatorSeriesStore = await calculateIndicators(
            items: items,
            selection: controller.state.indicatorSelection
        )
        guard !Task.isCancelled else { return }
        
        controller.state.items = items
        controller.state.indicatorSeriesStore = newIndicatorSeriesStore
        synchronizeLegacyFieldsFromController()
        layout.itemCount = items.count
        
        scrollView.scroll(to: scrollPosition)
        
        await updateDescriptor(recalculateValues: false)
    }
    
    private func drawIndicator(_ selection: IndicatorSelection, in section: ChartSection) async {
        guard section == .mainChart || section == .subChart else { return }
        guard !selections(in: section).contains(where: { $0.id == selection.id }) else { return }
        var state = controller.state.indicatorSelection
        if section == .mainChart {
            state.main.append(selection)
        } else {
            state.sub.append(selection)
        }
        controller.setIndicatorSelection(state)
        indicatorTypeView.setSelectedIndicators(controller.state.indicatorSelection)
        saveIndicatorSelection()
        descriptorUpdateTask?.cancel()
        await updateDescriptor(recalculateValues: true)
    }
    
    private func eraseIndicator(_ selection: IndicatorSelection, in section: ChartSection) {
        guard section == .mainChart || section == .subChart else { return }
        var state = controller.state.indicatorSelection
        let oldState = state
        if section == .mainChart {
            state.main.removeAll { $0.id == selection.id }
        } else {
            state.sub.removeAll { $0.id == selection.id }
        }
        guard state != oldState else { return }
        controller.setIndicatorSelection(state)
        indicatorTypeView.setSelectedIndicators(controller.state.indicatorSelection)
        saveIndicatorSelection()
        scheduleDescriptorUpdate()
    }
    
    private func selections(in section: ChartSection) -> [IndicatorSelection] {
        switch section {
        case .mainChart:
            return controller.state.indicatorSelection.main
        case .subChart:
            return controller.state.indicatorSelection.sub
        case .timeline:
            return []
        }
    }
    
    public func resetIndicatorsToDefault() {
        controller.resetIndicatorSelection()
        indicatorTypeView.setSelectedIndicators(controller.state.indicatorSelection)
        saveIndicatorSelection()
        scheduleDescriptorUpdate()
    }
    
    private func saveIndicatorSelection() {
        indicatorSelectionDidChange?(controller.state.indicatorSelection)
    }

    private func calculateIndicators(
        items: [any KLineItem],
        selection: IndicatorSelectionState
    ) async -> IndicatorSeriesStore {
        await controller.calculateIndicators(
            items: items,
            selection: selection,
            configuration: klineConfig
        )
    }

    private var selectedMainIndicatorIDs: [IndicatorID] {
        controller.state.indicatorSelection.main.map(\.id)
    }

    private var selectedSubIndicatorIDs: [IndicatorID] {
        controller.state.indicatorSelection.sub.map(\.id)
    }
    
    private func scheduleRedraw(_ mode: RedrawMode) {
        redrawScheduler.schedule(mode) { [weak self] redrawMode in
            self?.drawVisibleContent(mode: redrawMode)
        }
    }
}

#if DEBUG
extension KLineView {
    var debugSelectedBuiltInIndicators: (main: [KLineIndicator], sub: [KLineIndicator]) {
        (controller.state.mainIndicators, controller.state.subIndicators)
    }

    var debugSelectedIndicators: (main: [IndicatorSelection], sub: [IndicatorSelection]) {
        (controller.state.indicatorSelection.main, controller.state.indicatorSelection.sub)
    }

    var debugIndicatorTypeTitles: (main: [String], sub: [String]) {
        indicatorTypeView.debugTitles
    }

    func debugToggleIndicator(_ selection: IndicatorSelection, in section: ChartSection) {
        if selections(in: section).contains(where: { $0.id == selection.id }) {
            eraseIndicator(selection, in: section)
        } else {
            var state = controller.state.indicatorSelection
            if section == .mainChart {
                state.main.append(selection)
            } else if section == .subChart {
                state.sub.append(selection)
            }
            controller.setIndicatorSelection(state)
            indicatorTypeView.setSelectedIndicators(controller.state.indicatorSelection)
            saveIndicatorSelection()
            scheduleDescriptorUpdate()
        }
    }

    func debugDraw(items: [any KLineItem]) async {
        await draw(items: items, scrollPosition: .current)
    }

    var debugItemTimestamps: [Int] {
        klineItems.map(\.timestamp)
    }

    var debugControllerItemTimestamps: [Int] {
        controller.state.items.map(\.timestamp)
    }
}
#endif

// MARK: - 绘制内容
extension KLineView {
    
    private func drawVisibleContent(mode: RedrawMode = .full) {
        let drawStartTime = CACurrentMediaTime()
        var legendCost: CFTimeInterval = 0
        var boundsCost: CFTimeInterval = 0
        var rendererCost: CFTimeInterval = 0
        guard !klineItems.isEmpty else { return }
        
        // 防御性检查：确保 layout.itemCount 与 klineItems.count 一致
        // 虽然 draw() 方法已经保证了原子性更新，但这里保留检查作为额外保护
        guard layout.itemCount == klineItems.count else {
            return
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setAnimationDuration(0)
        defer { CATransaction.commit() }
        
        let contentRect = scrollView.contentView.bounds
        let visibleRange = layout.visibleRange
        if visibleRange.isEmpty { return }
        
        let context = RendererContext(
            indicatorSeriesStore: indicatorSeriesStore,
            items: klineItems,
            configuration: klineConfig,
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

extension KLineView {
    
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
                controller.state.selectedIndex = nil
                controller.state.selectedLocation = nil
                crosshairRenderer?.uninstall(from: self.scrollView.contentView.canvas)
                crosshairRenderer = nil
            }
            scheduleRedraw(.full)
            let loader = klineItemLoader
            let contentOffsetX = Double(scrollView.contentOffset.x)
            let viewportWidth = Double(scrollView.bounds.width)
            Task {
                await loader?.loadMoreIfNeeded(
                    contentOffsetX: contentOffsetX,
                    viewportWidth: viewportWidth
                )
            }
        }
    }
}

// MARK: - Live merging
private extension KLineView {
    func applyLiveTickMergeResult(
        _ result: LiveTickMergeResult?,
        shouldStickToRightEdge: Bool
    ) async {
        layout.itemCount = klineItems.count
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
        guard liveRedrawThrottle.shouldRedraw() else { return }
        scheduleDescriptorUpdate(recalculateValues: true)
    }
}

// MARK: - Network Observation
extension KLineView {
    
    private func setupNetworkObservation() {
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
    
    private func handleNetworkRecovery() {
        guard features.contains(.gapRecovery) else { return }
        // 网络恢复时，触发数据补全
        let latestTimestamp = klineItems.last?.timestamp
        let loader = klineItemLoader
        Task { await loader?.willEnterForeground(latestTimestamp: latestTimestamp) }
    }
    
    private func handleNetworkDisconnection() {
        guard features.contains(.gapRecovery) else { return }
        // 网络断开时，记录当前状态
        let latestTimestamp = klineItems.last?.timestamp
        let loader = klineItemLoader
        Task { await loader?.didEnterBackground(latestTimestamp: latestTimestamp) }
    }
}

extension KLineView: CrosshairInteractionDelegate {
    
    func updateCrosshair(location: CGPoint, itemIndex: Int) {
        // 根据 location 定位当前所在的 group
        selectedLocation = location
        selectedIndex = itemIndex
        controller.state.selectedLocation = location
        controller.state.selectedIndex = itemIndex
        if crosshairRenderer == nil {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            CATransaction.setAnimationDuration(0)
            defer { CATransaction.commit() }
            crosshairRenderer = CrosshairRenderer(configuration: klineConfig)
            crosshairRenderer?.install(to: scrollView.contentView.canvas)
        }
        scheduleRedraw(.crosshairOnly)
    }
}
