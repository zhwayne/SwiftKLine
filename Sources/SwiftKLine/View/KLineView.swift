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
    
    typealias IndicatorProvider = IndicatorRendererRegistry.Provider
    
    // MARK: - Views
    private let chartView = UIView()
    private let scrollView = ChartScrollView()
    private let legendLabel = UILabel()
    private var indicatorTypeView = IndicatorTypeView()
    private let watermarkLabel = UILabel()
    private lazy var layout = KLineLayout(scrollView: scrollView, configuration: klineConfig)
    private let klineConfig: KLineConfiguration
    private var indicatorSelectionStore: IndicatorSelectionStore?
    private let indicatorSelectionNormalizer: IndicatorSelectionNormalizer
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
    private var redrawScheduler = KLineRedrawScheduler()
    private var legendCache = KLineLegendCache<LegendCacheKey>()
    #if DEBUG
    private var debugDrawReporter = KLineDebugDrawReporter()
    #endif
    private var mainChartContent: KLineChartContentStyle = .candlestick
    private var descriptorUpdateTask: Task<Void, Never>? {
        didSet { oldValue?.cancel() }
    }
    
    // MARK: - Data
    private var mainIndicatorTypes: [Indicator] = []
    private var subIndicatorTypes: [Indicator] = []
    private var klineItems: [any KLineItem] = []
    private var indicatorSeriesStore = IndicatorSeriesStore()
    private let indicatorCalculationEngine = IndicatorCalculationEngine()
    private let descriptorFactory = KLineDescriptorFactory()
    private let rendererReconciler = KLineRendererReconciler()
    private let crosshairDrawCoordinator = KLineCrosshairDrawCoordinator()
    private let groupDrawCoordinator = KLineGroupDrawCoordinator()
    private let legendCoordinator = KLineLegendCoordinator()
    private let visibleContentCoordinator = KLineVisibleContentCoordinator()
    private var selectedIndex: Int?
    private var selectedLocation: CGPoint?
    private var longPressLocation: CGPoint = .zero
    private var dataMerger = KLineDataMerger()
    public var indicatorSelectionDidChange: ((IndicatorSelectionState) -> Void)?
    public var onLoadError: ((Error) -> Void)?
    
    private var disposeBag = Set<AnyCancellable>()
    private var liveRedrawThrottle = KLineLiveRedrawThrottle()
    private var klineItemLoader: KLineItemLoader?
    private var loaderGeneration = UUID()
    private let networkObserver = KLineNetworkObserver()
    
    // MARK: - Initializers
    public init(
        frame: CGRect = .zero,
        configuration: KLineConfiguration = KLineConfiguration(),
        indicatorSelectionStore: IndicatorSelectionStore? = UserDefaultsIndicatorSelectionStore()
    ) {
        self.klineConfig = configuration
        self.indicatorSelectionStore = indicatorSelectionStore
        let availableMain = configuration.indicators.filter { $0.isMain && !$0.defaultKeys.isEmpty }
        let availableSub = configuration.indicators.filter { !$0.isMain && !$0.defaultKeys.isEmpty }
        self.indicatorSelectionNormalizer = IndicatorSelectionNormalizer(
            availableMain: availableMain,
            availableSub: availableSub
        )
        super.init(frame: frame)
        chartView.layer.masksToBounds = true
        indicatorTypeView.mainIndicators = availableMain
        indicatorTypeView.subIndicators = availableSub
        let persistedState = indicatorSelectionNormalizer.normalize(indicatorSelectionStore?.load())
        let normalizedMain = persistedState.mainIndicators
        let normalizedSub = persistedState.subIndicators
        mainIndicatorTypes = normalizedMain.isEmpty ? klineConfig.defaultMainIndicators : normalizedMain
        subIndicatorTypes = normalizedSub.isEmpty ? klineConfig.defaultSubIndicators : normalizedSub
        indicatorTypeView.setSelectedIndicators(main: mainIndicatorTypes, sub: subIndicatorTypes)
        
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
        setupNetworkObservation()
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
            .sink { [unowned self] section, type in
                Task(priority: .userInitiated) {
                    if section == .mainChart {
                        await drawMainIndicator(type: type)
                    } else {
                        await drawSubIndicator(type: type)
                    }
                }
            }
            .store(in: &disposeBag)
        
        indicatorTypeView.eraseIndicatorPublisher
            .sink { [unowned self] section, type in
                if section == .mainChart {
                    eraseMainIndicator(type: type)
                } else {
                    eraseSubIndicator(type: type)
                }
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
    
    public func loadData(using provider: some KLineItemProvider) {
        descriptorUpdateTask?.cancel()
        let oldLoader = klineItemLoader
        Task { await oldLoader?.stop() }
        klineItemLoader = nil
        klineItems = []
        indicatorSeriesStore = IndicatorSeriesStore()
        liveRedrawThrottle.reset()
        dataMerger.reset()
        let generation = UUID()
        loaderGeneration = generation
        
        klineItemLoader = KLineItemLoader(
            provider: provider,
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
        let latestTimestamp = klineItems.last?.timestamp
        let loader = klineItemLoader
        Task { await loader?.didEnterBackground(latestTimestamp: latestTimestamp) }
    }
    
    func handleWillEnterForeground() {
        let latestTimestamp = klineItems.last?.timestamp
        let loader = klineItemLoader
        Task { await loader?.willEnterForeground(latestTimestamp: latestTimestamp) }
    }

    func handleLoaderEvent(_ event: KLineItemLoaderEvent) {
        Task { [weak self] in
            guard let self else { return }
            switch event {
            case let .page(index, items):
                if index == 0 {
                    await self.draw(items: items, scrollPosition: .right)
                } else {
                    let merged = self.dataMerger.merge(current: self.klineItems, patch: items)
                    await self.draw(items: merged, scrollPosition: .current)
                }
            case let .recovery(items):
                let merged = self.dataMerger.merge(current: self.klineItems, patch: items)
                await self.draw(items: merged, scrollPosition: .right)
            case let .liveTick(tick):
                await self.applyLiveTick(tick)
            case let .failed(error):
                onLoadError?(error)
            }
        }
    }
}

// MARK: - 切换主图模式
extension KLineView {
    
    public func setChartContentStyle(_ style: KLineChartContentStyle) {
        guard mainChartContent != style else { return }
        mainChartContent = style
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
            let store = await indicatorCalculationEngine.calculate(
                items: klineItems,
                mainIndicators: mainIndicatorTypes,
                subIndicators: subIndicatorTypes,
                configuration: klineConfig
            )
            guard !Task.isCancelled else { return }
            indicatorSeriesStore = store
        }
        
        updateDescriptorAndDrawContent()
    }
    
    private func updateDescriptorAndDrawContent() {
        var newDescriptor = descriptorFactory.makeDescriptor(
            contentStyle: mainChartContent,
            mainIndicators: mainIndicatorTypes,
            subIndicators: subIndicatorTypes,
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
        
        let newIndicatorSeriesStore = await indicatorCalculationEngine.calculate(
            items: items,
            mainIndicators: mainIndicatorTypes,
            subIndicators: subIndicatorTypes,
            configuration: klineConfig
        )
        guard !Task.isCancelled else { return }
        
        dataMerger.prepareBucketsIfNeeded(with: items)
        // 3. 回到主线程，原子性地一次性更新所有状态
        // 此时数据已经准备好，避免中间状态
        klineItems = items
        indicatorSeriesStore = newIndicatorSeriesStore
        layout.itemCount = items.count  // 现在可以安全地触发 layoutSubviews
        
        // 4. 调整滚动位置
        scrollView.scroll(to: scrollPosition)
        
        // 5. 更新渲染器描述符（不需要重新计算指标序列）
        await updateDescriptor(recalculateValues: false)
    }
    
    private func drawMainIndicator(type: Indicator) async {
        guard !mainIndicatorTypes.contains(type) else { return }
        mainIndicatorTypes.append(type)
        saveIndicatorSelection()
        descriptorUpdateTask?.cancel()
        await updateDescriptor(recalculateValues: true)
    }
    
    private func eraseMainIndicator(type: Indicator) {
        guard let index = mainIndicatorTypes.firstIndex(of: type) else { return }
        mainIndicatorTypes.remove(at: index)
        saveIndicatorSelection()
        scheduleDescriptorUpdate()
    }
    
    private func drawSubIndicator(type: Indicator) async {
        guard !subIndicatorTypes.contains(type) else { return }
        subIndicatorTypes.append(type)
        saveIndicatorSelection()
        descriptorUpdateTask?.cancel()
        await updateDescriptor(recalculateValues: true)
    }
    
    private func eraseSubIndicator(type: Indicator) {
        guard let index = subIndicatorTypes.firstIndex(of: type) else { return }
        subIndicatorTypes.remove(at: index)
        saveIndicatorSelection()
        scheduleDescriptorUpdate()
    }
    
    public func resetIndicatorsToDefault() {
        mainIndicatorTypes = klineConfig.defaultMainIndicators
        subIndicatorTypes = klineConfig.defaultSubIndicators
        indicatorSelectionStore?.reset()
        indicatorTypeView.setSelectedIndicators(main: mainIndicatorTypes, sub: subIndicatorTypes)
        saveIndicatorSelection()
        scheduleDescriptorUpdate()
    }
    
    private func saveIndicatorSelection() {
        let normalized = indicatorSelectionNormalizer.normalize(
            IndicatorSelectionState(
                mainIndicators: mainIndicatorTypes,
                subIndicators: subIndicatorTypes
            )
        )
        indicatorSelectionStore?.save(state: normalized)
        indicatorSelectionDidChange?(normalized)
    }
    
    private func scheduleRedraw(_ mode: KLineRedrawMode) {
        redrawScheduler.schedule(mode) { [weak self] redrawMode in
            self?.drawVisibleContent(mode: redrawMode)
        }
    }
}

// MARK: - 绘制内容
extension KLineView {
    
    private func drawVisibleContent(mode: KLineRedrawMode = .full) {
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
                rendererIDsHash: KLineLegendCache<LegendCacheKey>.rendererIDsHash(group.renderers)
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
    func applyLiveTick(_ tick: any KLineItem) async {
        let shouldStickToRightEdge = scrollView.isNearRightEdge
        let result = dataMerger.applyLiveTick(tick, to: &klineItems)
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
        // 网络恢复时，触发数据补全
        let latestTimestamp = klineItems.last?.timestamp
        let loader = klineItemLoader
        Task { await loader?.willEnterForeground(latestTimestamp: latestTimestamp) }
    }
    
    private func handleNetworkDisconnection() {
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

extension KLineView {
    
    public static func registerRenderer(
        for indicator: Indicator,
        provider: @escaping (Indicator, KLineConfiguration) -> (some Renderer)
    ) {
        IndicatorRendererRegistry.shared.register(for: indicator, provider: provider)
    }
}
