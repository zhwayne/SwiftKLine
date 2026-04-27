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
    private enum RedrawMode {
        case crosshairOnly
        case full
        
        func merged(with newValue: RedrawMode) -> RedrawMode {
            if self == .full || newValue == .full {
                return .full
            }
            return .crosshairOnly
        }
    }
    private struct LegendCacheKey: Hashable {
        let groupIndex: Int
        let currentIndex: Int
        let colorSignature: ColorAppearanceSignature
        let rendererIDsHash: Int
    }
    private struct LegendCacheValue {
        let text: NSAttributedString
        let size: CGSize
    }
    private let legendCacheCapacity = 256
    private var isRedrawScheduled = false
    private var pendingRedrawMode: RedrawMode = .full
    private var legendCache: [LegendCacheKey: LegendCacheValue] = [:]
    private var lastMainLegendCacheKey: LegendCacheKey?
    #if DEBUG
    private struct DebugDrawMetrics {
        var frameCount: Int = 0
        var lastReportTime: CFTimeInterval = CACurrentMediaTime()
    }
    private var debugDrawMetrics = DebugDrawMetrics()
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
    private var selectedIndex: Int?
    private var selectedLocation: CGPoint?
    private var longPressLocation: CGPoint = .zero
    private var dataMerger = KLineDataMerger()
    public var indicatorSelectionDidChange: ((IndicatorSelectionState) -> Void)?
    
    private var disposeBag = Set<AnyCancellable>()
    private var lastLiveRedrawAt: TimeInterval = 0
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
        super.init(frame: frame)
        chartView.layer.masksToBounds = true
        let availableMain = klineConfig.indicators.filter { $0.isMain && !$0.defaultKeys.isEmpty }
        let availableSub = klineConfig.indicators.filter { !$0.isMain && !$0.defaultKeys.isEmpty }
        indicatorTypeView.mainIndicators = availableMain
        indicatorTypeView.subIndicators = availableSub
        let persistedState = normalizedSelectionState(indicatorSelectionStore?.load())
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
        clearLegendCache()
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
        lastLiveRedrawAt = 0
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
            case .failed:
                break
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
    
    private func makeDescriptor() -> ChartDescriptor {
        ChartDescriptor {
            // MARK: - 主图
            RendererGroup(chartSection: .mainChart, height: candleHeight, padding: (16, 12)) {
                XAxisRenderer()
                if mainChartContent == .timeSeries {
                    TimeSeriesRenderer(style: TimeSeriesStyle())
                    // Y轴
                    YAxisRenderer()
                } else {
                    CandleRenderer()
                    // 主图指标
                    for type in mainIndicatorTypes {
                        for renderer in IndicatorRendererRegistry.shared.renderers(for: type, configuration: klineConfig) {
                            renderer
                        }
                    }
                    // 自定义主图渲染器
                    for renderer in customRenderers {
                        renderer
                    }
                    // Y轴
                    YAxisRenderer()
                    // 价格相关
                    PriceIndicatorRenderer(style: PriceIndicatorStyle())
                }
            }
            // MARK: - Timeline
            RendererGroup(chartSection: .timeline, height: timelineHeight, padding: (0, 0)) {
                TimeAxisRenderer(style: TimeAxisStyle())
            }
            // MARK: - 副图
            for type in subIndicatorTypes {
                RendererGroup(chartSection: .subChart, height: indicatorHeight) {
                    XAxisRenderer()
                    for renderer in IndicatorRendererRegistry.shared.renderers(for: type, configuration: klineConfig) {
                        renderer
                    }
                }
            }
        }
    }
    
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
        var newDescriptor = makeDescriptor()
        let oldDescriptor = descriptor
        let transition = reconcileRenderers(from: oldDescriptor, to: &newDescriptor)
        
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
        clearLegendCache()
        invalidateIntrinsicContentSize()
        scheduleRedraw(.full)
    }
    
    private func reconcileRenderers(
        from oldDescriptor: ChartDescriptor,
        to newDescriptor: inout ChartDescriptor
    ) -> (added: [AnyRenderer], removed: [AnyRenderer]) {
        struct RendererReuseKey: Hashable {
            let id: AnyHashable
            let zIndex: Int
        }
        
        var available = Dictionary(grouping: oldDescriptor.renderers) { renderer in
            RendererReuseKey(id: AnyHashable(renderer.id), zIndex: renderer.zIndex)
        }
        var additions = [AnyRenderer]()
        var reused = Set<ObjectIdentifier>()
        
        for groupIndex in newDescriptor.groups.indices {
            var renderers = newDescriptor.groups[groupIndex].renderers
            for rendererIndex in renderers.indices {
                let renderer = renderers[rendererIndex]
                let key = RendererReuseKey(id: AnyHashable(renderer.id), zIndex: renderer.zIndex)
                if var bucket = available[key], let reusedRenderer = bucket.popLast() {
                    renderers[rendererIndex] = reusedRenderer
                    reused.insert(ObjectIdentifier(reusedRenderer))
                    available[key] = bucket.isEmpty ? nil : bucket
                } else {
                    additions.append(renderer)
                }
            }
            newDescriptor.groups[groupIndex].renderers = renderers
        }
        
        let removals = oldDescriptor.renderers.filter { renderer in
            !reused.contains(ObjectIdentifier(renderer))
        }
        return (additions, removals)
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
        let normalized = normalizedSelectionState(
            IndicatorSelectionState(
                mainIndicators: mainIndicatorTypes,
                subIndicators: subIndicatorTypes
            )
        )
        indicatorSelectionStore?.save(state: normalized)
        indicatorSelectionDidChange?(normalized)
    }
    
    private func normalizedSelectionState(_ state: IndicatorSelectionState?) -> IndicatorSelectionState {
        let availableMain = Set(indicatorTypeView.mainIndicators)
        let availableSub = Set(indicatorTypeView.subIndicators)
        let main = deduplicatedIndicators(state?.mainIndicators ?? [], validSet: availableMain)
        let sub = deduplicatedIndicators(state?.subIndicators ?? [], validSet: availableSub)
        return IndicatorSelectionState(mainIndicators: main, subIndicators: sub)
    }
    
    private func deduplicatedIndicators(_ indicators: [Indicator], validSet: Set<Indicator>) -> [Indicator] {
        var seen = Set<Indicator>()
        var result: [Indicator] = []
        for indicator in indicators where validSet.contains(indicator) && !seen.contains(indicator) {
            result.append(indicator)
            seen.insert(indicator)
        }
        return result
    }
    
    private func clearLegendCache() {
        legendCache.removeAll(keepingCapacity: true)
        lastMainLegendCacheKey = nil
    }
    
    private func cacheLegend(_ value: LegendCacheValue, for key: LegendCacheKey) {
        if legendCache.count >= legendCacheCapacity {
            legendCache.removeAll(keepingCapacity: true)
            lastMainLegendCacheKey = nil
        }
        legendCache[key] = value
    }
    
    private func scheduleRedraw(_ mode: RedrawMode) {
        pendingRedrawMode = pendingRedrawMode.merged(with: mode)
        guard !isRedrawScheduled else { return }
        isRedrawScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isRedrawScheduled = false
            let redrawMode = self.pendingRedrawMode
            self.pendingRedrawMode = .crosshairOnly
            self.drawVisibleContent(mode: redrawMode)
        }
    }
}

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

        func makeLegendText(for renderers: [AnyRenderer]) -> NSMutableAttributedString {
            let legendText = NSMutableAttributedString()
            for renderer in renderers {
                guard let string = renderer.legend(context: context) else { continue }
                if !legendText.string.isEmpty {
                    legendText.append(NSAttributedString(string: "\n"))
                }
                legendText.append(string)
            }
            return legendText
        }

        func rendererIDsHash(_ renderers: [AnyRenderer]) -> Int {
            var hasher = Hasher()
            for renderer in renderers {
                hasher.combine(AnyHashable(renderer.id))
                hasher.combine(renderer.zIndex)
            }
            return hasher.finalize()
        }
        
        func configureLegend(for group: RendererGroup, groupIndex: Int, groupFrame: CGRect) -> CGFloat {
            let legendKey = LegendCacheKey(
                groupIndex: groupIndex,
                currentIndex: context.currentIndex,
                colorSignature: currentColorSignature,
                rendererIDsHash: rendererIDsHash(group.renderers)
            )
            let legendStart = CACurrentMediaTime()
            let cachedLegend = legendCache[legendKey]
            let legendText = cachedLegend?.text ?? makeLegendText(for: group.renderers)
            legendCost += CACurrentMediaTime() - legendStart
            guard !legendText.string.isEmpty else {
                if group.chartSection == .mainChart {
                    legendLabel.attributedText = nil
                    lastMainLegendCacheKey = nil
                }
                context.legendText = nil
                context.legendFrame = .zero
                return 0
            }

            context.legendText = legendText
            if group.chartSection == .mainChart {
                if lastMainLegendCacheKey != legendKey {
                    legendLabel.attributedText = legendText
                    if let cachedLegend {
                        legendLabel.frame.size = cachedLegend.size
                    } else {
                        legendLabel.sizeToFit()
                    }
                    lastMainLegendCacheKey = legendKey
                }
                let legendFrame = CGRect(origin: legendLabel.frame.origin, size: legendLabel.frame.size)
                context.legendFrame = legendFrame
                if legendCache[legendKey] == nil {
                    cacheLegend(LegendCacheValue(text: legendText, size: legendFrame.size), for: legendKey)
                }
                return legendFrame.maxY
            }
            
            let measuredSize: CGSize
            if let cachedLegend {
                measuredSize = cachedLegend.size
            } else {
                let boundingRect = legendText.boundingRect(
                    with: CGSize(width: groupFrame.width * 0.8, height: groupFrame.height),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                measuredSize = boundingRect.size
                cacheLegend(LegendCacheValue(text: legendText, size: measuredSize), for: legendKey)
            }
            context.legendFrame = CGRect(
                x: 12, y: groupFrame.minY + group.padding.top,
                width: measuredSize.width, height: measuredSize.height
            )
            return measuredSize.height + group.legendSpacing
        }

        func configureCrosshairRenderer(_ renderer: CrosshairRenderer) {
            for group in descriptor.groups {
                if group.chartSection == .mainChart {
                    renderer.candleGroup = group
                } else if group.chartSection == .timeline {
                    renderer.timelineGroup = group
                }
            }
        }

        @discardableResult
        func drawCrosshairIfPossible(at location: CGPoint) -> Bool {
            guard let renderer = crosshairRenderer,
                  let groupIndex = descriptor.indexOfGroup(at: location) else {
                return false
            }

            let group = descriptor.groups[groupIndex]
            guard !group.groupFrame.isEmpty, !group.viewPort.isEmpty else { return false }

            renderer.selectedGroup = group
            configureCrosshairRenderer(renderer)
            context.groupFrame = group.groupFrame
            context.viewPort = group.viewPort
            context.layout.dataBounds = group.dataBounds
            renderer.draw(in: scrollView.contentView.canvas, context: context)
            return true
        }

        if hasCrosshairRenderer, let location = crosshairLocation {
            defer { _ = drawCrosshairIfPossible(at: location) }
        }

        if canUseCrosshairFastPath,
           let location = crosshairLocation,
           let selectedGroupIndex = descriptor.indexOfGroup(at: location),
           !descriptor.groups[selectedGroupIndex].viewPort.isEmpty {
            for idx in descriptor.groups.indices {
                let groupFrame = descriptor.frameOfGroup(at: idx, rect: contentRect)
                descriptor.groups[idx].groupFrame = groupFrame
                context.groupFrame = groupFrame

                let group = descriptor.groups[idx]
                _ = configureLegend(for: group, groupIndex: idx, groupFrame: groupFrame)
                for renderer in group.renderers {
                    (renderer.base as? LegendUpdatable)?.updateLegend(context: context)
                }
            }
            #if DEBUG
            reportDrawMetrics(
                drawStartTime: drawStartTime,
                legendCost: legendCost,
                boundsCost: boundsCost,
                rendererCost: rendererCost,
                mode: mode
            )
            #endif
            return
        }

        for (idx, group) in descriptor.groups.enumerated() {
            let renderers = group.renderers

            var dataBounds: MetricBounds = .empty
            let boundsStart = CACurrentMediaTime()
            // 计算可见区域内数据范围
            for renderer in renderers {
                dataBounds.merge(other: renderer.dataBounds(context: context))
            }
            boundsCost += CACurrentMediaTime() - boundsStart
            descriptor.groups[idx].dataBounds = dataBounds
            context.layout.dataBounds = dataBounds

            // 计算可见区域内每个 group 所在的位置
            let groupFrame = descriptor.frameOfGroup(at: idx, rect: contentRect)
            descriptor.groups[idx].groupFrame = groupFrame
            context.groupFrame = groupFrame

            // 绘制图例
            let viewPortOffsetY = configureLegend(for: group, groupIndex: idx, groupFrame: groupFrame)

            // 计算 viewPort
            let groupInset = UIEdgeInsets(
                top: group.padding.top + viewPortOffsetY, left: 0,
                bottom: group.padding.bottom, right: 0
            )
            let viewPort = groupFrame.inset(by: groupInset)
            descriptor.groups[idx].viewPort = viewPort
            context.viewPort = viewPort

            // 绘制图表
            let renderersStart = CACurrentMediaTime()
            for renderer in renderers {
                renderer.draw(in: scrollView.contentView.canvas, context: context)
            }
            rendererCost += CACurrentMediaTime() - renderersStart
        }

        lastFullDrawColorSignature = currentColorSignature
        #if DEBUG
        reportDrawMetrics(
            drawStartTime: drawStartTime,
            legendCost: legendCost,
            boundsCost: boundsCost,
            rendererCost: rendererCost,
            mode: mode
        )
        #endif
    }
    
    #if DEBUG
    private func reportDrawMetrics(
        drawStartTime: CFTimeInterval,
        legendCost: CFTimeInterval,
        boundsCost: CFTimeInterval,
        rendererCost: CFTimeInterval,
        mode: RedrawMode
    ) {
        debugDrawMetrics.frameCount += 1
        let now = CACurrentMediaTime()
        guard now - debugDrawMetrics.lastReportTime >= 1 else { return }
        let totalCost = now - drawStartTime
        print(
            "[SwiftKLine][Perf] fps=\(debugDrawMetrics.frameCount)/s mode=\(mode) " +
            "total=\(String(format: "%.4f", totalCost))s " +
            "legend=\(String(format: "%.4f", legendCost))s " +
            "bounds=\(String(format: "%.4f", boundsCost))s " +
            "render=\(String(format: "%.4f", rendererCost))s"
        )
        debugDrawMetrics.frameCount = 0
        debugDrawMetrics.lastReportTime = now
    }
    #endif
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
        let now = CACurrentMediaTime()
        guard now - lastLiveRedrawAt >= 0.2 else { return }
        lastLiveRedrawAt = now
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
