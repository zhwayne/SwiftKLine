//
//  KLineView.swift
//  KLineDemo
//
//  Created by iya on 2024/10/31.
//

import UIKit
import SnapKit
import Combine
import Network

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
    private enum MainChartContent {
        case candlestick
        case timeSeries
    }
    private var mainChartContent: MainChartContent = .candlestick
    private var descriptorUpdateTask: Task<Void, Never>? {
        didSet { oldValue?.cancel() }
    }
    
    // MARK: - Data
    private var mainIndicatorTypes: [Indicator] = []
    private var subIndicatorTypes: [Indicator] = []
    private var klineItems: [any KLineItem] = []
    private let indicatorValueCache = IndicatorValueCache()
    private var valueStorage = ValueStorage()
    private var selectedIndex: Int?
    private var selectedLocation: CGPoint?
    private var longPressLocation: CGPoint = .zero
    private var bucketDuration: Int?
    public var indicatorSelectionDidChange: ((IndicatorSelectionState) -> Void)?
    
    private var disposeBag = Set<AnyCancellable>()
    private var lastLiveRedrawAt: TimeInterval = 0
    private var klineItemLoader: KLineItemLoader?
    
    // MARK: - Network Monitoring
    private var networkMonitor: NWPathMonitor?
    private var networkQueue = DispatchQueue(label: "NetworkMonitor")
    private var isNetworkAvailable = true
    
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
        setupNetworkMonitoring()
        updateDescriptorAndDrawContent()
        scheduleDescriptorUpdate()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        descriptorUpdateTask?.cancel()
        klineItemLoader?.stop()
        networkMonitor?.cancel()
    }
    
    private func addInteractions() {
        let pinchInteraction = PinchInteraction(layout: layout, configuration: klineConfig)
        chartView.addInteraction(pinchInteraction)
        let crosshairInteraction = CrosshairInteraction(layout: layout, delegate: self, configuration: klineConfig)
        chartView.addInteraction(crosshairInteraction)
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        drawVisibleContent()
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
    
    public func setProvider(_ provider: some KLineItemProvider) {
        descriptorUpdateTask?.cancel()
        klineItemLoader?.stop()
        klineItemLoader = nil
        klineItems = []
        valueStorage = ValueStorage()
        Task { await indicatorValueCache.reset() }
        lastLiveRedrawAt = 0
        bucketDuration = nil
        
        klineItemLoader = KLineItemLoader(
            provider: provider,
            snapshotHandler: { [weak self] page, items in
                guard let self else { return }
                if page == -1 {
                    let merged = await self.mergedItems(current: self.klineItems, patch: items)
                    await self.draw(items: merged, scrollPosition: .right)
                } else if page == 0 {
                    await self.draw(items: items, scrollPosition: .right)
                } else {
                    let merged = await items + self.klineItems
                    await self.draw(items: merged, scrollPosition: .current)
                }
            },
            liveHandler: { [weak self] tick in
                guard let self else { return }
                await self.applyLiveTick(tick)
            }
        )
        klineItemLoader?.start()
    }
}

private extension KLineView {
    func handleDidEnterBackground() {
        let latestTimestamp = klineItems.last?.timestamp
        klineItemLoader?.didEnterBackground(latestTimestamp: latestTimestamp)
    }
    
    func handleWillEnterForeground() {
        let latestTimestamp = klineItems.last?.timestamp
        klineItemLoader?.willEnterForeground(latestTimestamp: latestTimestamp)
    }
    
    func mergedItems(current: [any KLineItem], patch: [any KLineItem]) -> [any KLineItem] {
        guard !current.isEmpty else { return patch }
        var map = Dictionary(uniqueKeysWithValues: current.map { ($0.timestamp, $0) })
        for item in patch {
            map[item.timestamp] = item
        }
        return map.values.sorted { $0.timestamp < $1.timestamp }
    }
    
    func updateBucketDurationIfNeeded(with items: [any KLineItem]) {
        guard bucketDuration == nil else { return }
        let timestamps = items.map(\.timestamp).sorted()
        guard timestamps.count >= 2 else { return }
        var minDiff: Int?
        for index in 1..<timestamps.count {
            let diff = timestamps[index] - timestamps[index - 1]
            guard diff > 0 else { continue }
            minDiff = min(minDiff ?? diff, diff)
        }
        bucketDuration = minDiff
    }
    
    func bucketStart(for timestamp: Int) -> Int {
        guard let bucketDuration, bucketDuration > 0 else { return timestamp }
        return (timestamp / bucketDuration) * bucketDuration
    }
    
    func indexOfBucket(for timestamp: Int) -> Int? {
        let target = bucketStart(for: timestamp)
        return klineItems.firstIndex { bucketStart(for: $0.timestamp) == target }
    }
    
    func insertionIndexForBucket(_ timestamp: Int) -> Int {
        let target = bucketStart(for: timestamp)
        return klineItems.firstIndex { bucketStart(for: $0.timestamp) > target } ?? klineItems.endIndex
    }
}

// MARK: - 切换主图模式
extension KLineView {
    
    public func useTimeSeries() {
        mainChartContent = .timeSeries
        scheduleDescriptorUpdate()
    }
    
    public func useCandlesticks() {
        guard mainChartContent != .candlestick else { return }
        mainChartContent = .candlestick
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
    
    private func scheduleDescriptorUpdate() {
        descriptorUpdateTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.updateDescriptor()
        }
    }
    
    @MainActor
    private func updateDescriptor() async {
        guard !Task.isCancelled else { return }
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
        invalidateIntrinsicContentSize()
        drawVisibleContent()
    }
    
    private func reconcileRenderers(
        from oldDescriptor: ChartDescriptor,
        to newDescriptor: inout ChartDescriptor
    ) -> (added: [AnyRenderer], removed: [AnyRenderer]) {
        var available = Dictionary(grouping: oldDescriptor.renderers) { renderer in
            AnyHashable(renderer.id)
        }
        var additions = [AnyRenderer]()
        var reused = Set<ObjectIdentifier>()
        
        for groupIndex in newDescriptor.groups.indices {
            var renderers = newDescriptor.groups[groupIndex].renderers
            for rendererIndex in renderers.indices {
                let renderer = renderers[rendererIndex]
                let key = AnyHashable(renderer.id)
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
        descriptorUpdateTask?.cancel()
        
        let change = dataChange(from: klineItems, to: items)
        let keys = currentIndicatorKeys()
        valueStorage = await rebuildIndicatorValues(keys: keys, items: items, change: change)
        
        updateBucketDurationIfNeeded(with: items)
        klineItems = items
        layout.itemCount = items.count
        
        scrollView.scroll(to: scrollPosition)
        await updateDescriptor()
    }
    
    private func drawMainIndicator(type: Indicator) async {
        guard !mainIndicatorTypes.contains(type) else { return }
        mainIndicatorTypes.append(type)
        saveIndicatorSelection()
        descriptorUpdateTask?.cancel()
        let keys = klineConfig.indicatorKeys(for: type)
        valueStorage = await rebuildIndicatorValues(keys: keys, items: klineItems, change: .reset)
        await updateDescriptor()
    }
    
    private func eraseMainIndicator(type: Indicator) {
        guard let index = mainIndicatorTypes.firstIndex(of: type) else { return }
        mainIndicatorTypes.remove(at: index)
        saveIndicatorSelection()
        Task { [weak self] in
            guard let self else { return }
            await indicatorValueCache.remove(keys: klineConfig.indicatorKeys(for: type))
            self.valueStorage = await indicatorValueCache.valueStorage
        }
        scheduleDescriptorUpdate()
    }
    
    private func drawSubIndicator(type: Indicator) async {
        guard !subIndicatorTypes.contains(type) else { return }
        subIndicatorTypes.append(type)
        saveIndicatorSelection()
        descriptorUpdateTask?.cancel()
        let keys = klineConfig.indicatorKeys(for: type)
        valueStorage = await rebuildIndicatorValues(keys: keys, items: klineItems, change: .reset)
        await updateDescriptor()
    }
    
    private func eraseSubIndicator(type: Indicator) {
        guard let index = subIndicatorTypes.firstIndex(of: type) else { return }
        subIndicatorTypes.remove(at: index)
        saveIndicatorSelection()
        Task { [weak self] in
            guard let self else { return }
            await indicatorValueCache.remove(keys: klineConfig.indicatorKeys(for: type))
            self.valueStorage = await indicatorValueCache.valueStorage
        }
        scheduleDescriptorUpdate()
    }
    
    public func resetIndicatorsToDefault() {
        mainIndicatorTypes = klineConfig.defaultMainIndicators
        subIndicatorTypes = klineConfig.defaultSubIndicators
        indicatorSelectionStore?.reset()
        indicatorTypeView.setSelectedIndicators(main: mainIndicatorTypes, sub: subIndicatorTypes)
        saveIndicatorSelection()
        let keys = currentIndicatorKeys()
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            self.valueStorage = await self.rebuildIndicatorValues(keys: keys, items: self.klineItems, change: .reset)
            await self.updateDescriptor()
        }
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
    
    private func currentIndicatorKeys() -> [Indicator.Key] {
        var seen = Set<Indicator.Key>()
        var keys: [Indicator.Key] = []
        for indicator in (mainIndicatorTypes + subIndicatorTypes) {
            for key in klineConfig.indicatorKeys(for: indicator) where !seen.contains(key) {
                seen.insert(key)
                keys.append(key)
            }
        }
        return keys
    }
    
    private func rebuildIndicatorValues(
        keys: [Indicator.Key],
        items: [any KLineItem],
        change: IndicatorValueChange
    ) async -> ValueStorage {
        guard !keys.isEmpty else {
            await indicatorValueCache.reset()
            return await indicatorValueCache.valueStorage
        }
        return await indicatorValueCache.rebuild(
            keys: keys,
            items: items,
            change: change
        )
    }
    
    private func dataChange(
        from oldItems: [any KLineItem],
        to newItems: [any KLineItem]
    ) -> IndicatorValueChange {
        guard !oldItems.isEmpty else { return .reset }
        let oldCount = oldItems.count
        let newCount = newItems.count
        
        if newCount > oldCount {
            let suffix = newItems.suffix(oldCount)
            if suffix.elementsEqual(oldItems, by: areItemsEqual) {
                return .prepend(count: newCount - oldCount)
            }
            let prefix = newItems.prefix(oldCount)
            if prefix.elementsEqual(oldItems, by: areItemsEqual) {
                return .append(count: newCount - oldCount)
            }
        }
        
        if let range = diffRange(old: oldItems, new: newItems) {
            return .patch(range: range)
        }
        return .none
    }
    
    private func diffRange(
        old: [any KLineItem],
        new: [any KLineItem]
    ) -> Range<Int>? {
        let minCount = Swift.min(old.count, new.count)
        var firstDiff: Int?
        var lastDiff: Int?
        
        for index in 0..<minCount {
            if !areItemsEqual(old[index], new[index]) {
                firstDiff = firstDiff ?? index
                lastDiff = index
            }
        }
        
        if new.count != old.count {
            firstDiff = firstDiff ?? minCount
            let upper = Swift.max(old.count, new.count) - 1
            lastDiff = max(lastDiff ?? firstDiff ?? 0, upper)
        }
        
        if let firstDiff, let lastDiff {
            return firstDiff..<(lastDiff + 1)
        }
        return nil
    }
    
    private func areItemsEqual(_ lhs: any KLineItem, _ rhs: any KLineItem) -> Bool {
        lhs.timestamp == rhs.timestamp &&
        lhs.opening == rhs.opening &&
        lhs.closing == rhs.closing &&
        lhs.highest == rhs.highest &&
        lhs.lowest == rhs.lowest &&
        lhs.volume == rhs.volume &&
        lhs.value == rhs.value
    }
}

// MARK: - 绘制内容
extension KLineView {
    
    private func drawVisibleContent() {
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
            valueStorage: valueStorage,
            items: klineItems,
            configuration: klineConfig,
            visibleRange: visibleRange,
            layout: layout,
            location: selectedLocation,
            selectedIndex: selectedIndex
        )
        
        for (idx, group) in descriptor.groups.enumerated() {
            let renderers = group.renderers
            
            var dataBounds: MetricBounds = .empty
            // 计算可见区域内数据范围
            for renderer in renderers {
                dataBounds.merge(other: renderer.dataBounds(context: context))
            }
            descriptor.groups[idx].dataBounds = dataBounds
            context.layout.dataBounds = dataBounds
            
            // 计算可见区域内每个 group 所在的位置
            let groupFrame = descriptor.frameOfGroup(at: idx, rect: contentRect)
            descriptor.groups[idx].groupFrame = groupFrame
            context.groupFrame = groupFrame
            
            // 绘制主图图例（副图图例暂由 renderer 自行处理）
            var viewPortOffsetY: CGFloat = 0
            let legendText = NSMutableAttributedString()
            for renderer in renderers {
                if let string = renderer.legend(context: context) {
                    if !legendText.string.isEmpty {
                        legendText.append(NSAttributedString(string: "\n"))
                    }
                    legendText.append(string)
                }
            }
            if legendText.string.isEmpty {
                if group.chartSection == .mainChart {
                    legendLabel.attributedText = nil
                }
            } else {
                context.legendText = legendText
                if group.chartSection == .mainChart {
                    legendLabel.attributedText = legendText
                    legendLabel.sizeToFit()
                    let legendFrame = legendLabel.frame
                    viewPortOffsetY = legendFrame.maxY
                    context.legendFrame = legendFrame
                } else {
                    let boundingRect = legendText.boundingRect(
                        with: CGSize(width: groupFrame.width * 0.8, height: groupFrame.height),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    )
                    viewPortOffsetY = boundingRect.height + group.legendSpacing
                    context.legendFrame = CGRect(
                        x: 12, y: groupFrame.minY + group.padding.top,
                        width: boundingRect.width, height: boundingRect.height
                    )
                }
            }
            
            // 计算 viewPort
            let groupInset = UIEdgeInsets(
                top: group.padding.top + viewPortOffsetY, left: 0,
                bottom: group.padding.bottom, right: 0
            )
            let viewPort = groupFrame.inset(by: groupInset)
            descriptor.groups[idx].viewPort = viewPort
            context.viewPort = viewPort
            
            // 绘制图表
            for renderer in renderers {
                renderer.draw(in: scrollView.contentView.canvas, context: context)
            }
        }
        
        // 绘制十字线
        if let location = selectedLocation,
           let renderer = crosshairRenderer,
           let groupIndex = descriptor.indexOfGroup(at: location) {
            let group = descriptor.groups[groupIndex]
            renderer.selectedGroup = group
            for group in descriptor.groups {
                if group.chartSection == .mainChart {
                    renderer.candleGroup = group
                } else if group.chartSection == .timeline {
                    renderer.timelineGroup = group
                }
            }
            context.groupFrame = group.groupFrame
            context.viewPort = group.viewPort
            context.layout.dataBounds = group.dataBounds
            renderer.draw(in: scrollView.contentView.canvas, context: context)
        }
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
            drawVisibleContent()
            klineItemLoader?.scrollViewDidScroll(scrollView: scrollView)
        }
    }
}

// MARK: - Live merging
private extension KLineView {
    func applyLiveTick(_ tick: any KLineItem) async {
        updateBucketDurationIfNeeded(with: klineItems + [tick])
        
        let shouldStickToRightEdge = scrollView.isNearRightEdge
        var change: IndicatorValueChange = .reset
        
        if klineItems.isEmpty {
            klineItems = [tick]
            layout.itemCount = 1
            change = .append(count: 1)
            if shouldStickToRightEdge {
                scrollView.scroll(to: .right)
            }
            throttleRecalculateAndRedraw(change: change)
            return
        }
        
        if let existingIndex = indexOfBucket(for: tick.timestamp) {
            klineItems[existingIndex] = tick
            change = .patch(range: existingIndex..<(existingIndex + 1))
        } else {
            let insertIndex = insertionIndexForBucket(tick.timestamp)
            let didAppendToTail = insertIndex == klineItems.endIndex
            klineItems.insert(tick, at: insertIndex)
            layout.itemCount = klineItems.count
            change = didAppendToTail ? .append(count: 1) : .patch(range: insertIndex..<(insertIndex + 1))
            if shouldStickToRightEdge && didAppendToTail {
                scrollView.scroll(to: .right)
            }
        }
        
        throttleRecalculateAndRedraw(change: change)
    }
    
    func throttleRecalculateAndRedraw(change: IndicatorValueChange) {
        let now = CACurrentMediaTime()
        guard now - lastLiveRedrawAt >= 0.2 else { return }
        lastLiveRedrawAt = now
        let keys = currentIndicatorKeys()
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            self.valueStorage = await self.rebuildIndicatorValues(keys: keys, items: self.klineItems, change: change)
            await self.updateDescriptor()
        }
    }
}

// MARK: - Network Monitoring
extension KLineView {
    
    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handleNetworkStatusChange(path.status == .satisfied)
            }
        }
        networkMonitor?.start(queue: networkQueue)
    }
    
    private func handleNetworkStatusChange(_ isAvailable: Bool) {
        let wasAvailable = isNetworkAvailable
        isNetworkAvailable = isAvailable
        
        if !wasAvailable && isAvailable {
            // 网络从断开恢复到连接
            handleNetworkRecovery()
        } else if wasAvailable && !isAvailable {
            // 网络从连接变为断开
            handleNetworkDisconnection()
        }
    }
    
    private func handleNetworkRecovery() {
        // 网络恢复时，触发数据补全
        let latestTimestamp = klineItems.last?.timestamp
        klineItemLoader?.willEnterForeground(latestTimestamp: latestTimestamp)
    }
    
    private func handleNetworkDisconnection() {
        // 网络断开时，记录当前状态
        let latestTimestamp = klineItems.last?.timestamp
        klineItemLoader?.didEnterBackground(latestTimestamp: latestTimestamp)
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
        drawVisibleContent()
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
