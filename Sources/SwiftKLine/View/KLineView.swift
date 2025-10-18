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
    
    public typealias IndicatorProvider = (Indicator) -> (any Renderer)?

    // MARK: - Views
    private let chartView = UIView()
    private let scrollView = ChartScrollView()
    private let legendLabel = UILabel()
    private var indicatorTypeView = IndicatorTypeView()
    private let watermarkLabel = UILabel()
    private lazy var layout = Layout(scrollView: scrollView)
    
    // MARK: - Height defines
    private let candleHeight: CGFloat = 320
    private let timelineHeight: CGFloat = 16
    private let indicatorHeight: CGFloat = 64
    private let indicatorTypeHeight: CGFloat = 32
    private var chartHeightConstraint: Constraint!
    private var viewHeight: CGFloat { descriptor.height + indicatorTypeHeight }
    
    // MARK: - ChartDescriptor
    private var descriptor = ChartDescriptor()
    private var customRenderers = [AnyRenderer]()
    private var crosshairRenderer: CrosshairRenderer?
    private var indiccatorProviderMap: [Indicator: IndicatorProvider] = [:]
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
    private var valueStorage = ValueStorage()
    private var selectedIndex: Int?
    private var selectedLocation: CGPoint?
    private var klineConfig: KLineConfig { .default }
    private var longPressLocation: CGPoint = .zero

    private var disposeBag = Set<AnyCancellable>()
    private var lastLiveRedrawAt: TimeInterval = 0
    private var klineItemLoader: KLineItemLoader?
    private var liveAnimator: Animator<InterpolatedKLineItem>?
    
    // MARK: - Network Monitoring
    private var networkMonitor: NWPathMonitor?
    private var networkQueue = DispatchQueue(label: "NetworkMonitor")
    private var isNetworkAvailable = true

    // MARK: - Initializers
    public override init(frame: CGRect) {
        super.init(frame: frame)
        chartView.layer.masksToBounds = true
        
        indicatorTypeView.mainIndicators = klineConfig.indicators.filter { $0.isMain && !$0.keys.isEmpty }
        indicatorTypeView.subIndicators =  klineConfig.indicators.filter { !$0.isMain && !$0.keys.isEmpty }
        
        addSubview(chartView)
        addSubview(indicatorTypeView)
        
        watermarkLabel.textAlignment = .center
        watermarkLabel.text = "Created by iyabb"
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
            make.width.equalToSuperview().multipliedBy(0.8)
            make.top.equalTo(8)
        }
        
        registerRenderers()
        addInteractions()
        observeScrollViewLayoutChange()
        setupBindings()
        setupNetworkMonitoring()
        scheduleDescriptorUpdate()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        MainActor.assumeIsolated {
            descriptorUpdateTask?.cancel()
            klineItemLoader?.stop()
            networkMonitor?.cancel()
            liveAnimator?.cancel()
        }
    }
    
    private func addInteractions() {
        let pinchInteraction = PinchInteraction(layout: layout)
        chartView.addInteraction(pinchInteraction)
        let crosshairInteraction = CrosshairInteraction(layout: layout, delegate: self)
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
        lastLiveRedrawAt = 0

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
                        if let rendererProvider = indiccatorProviderMap[type],
                           let renderer = rendererProvider(type) {
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
                    if let rendererProvider = indiccatorProviderMap[type],
                       let renderer = rendererProvider(type) {
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
            let calculators = (mainIndicatorTypes + subIndicatorTypes)
                .flatMap { indicator in indicator.makeCalculators() }
            if calculators.isEmpty {
                valueStorage = ValueStorage()
            } else {
                let storage = await calculators.calculate(items: klineItems)
                guard !Task.isCancelled else { return }
                valueStorage = storage
            }
        }

        var newDescriptor = makeDescriptor()
        let oldDescriptor = descriptor
        let transition = reconcileRenderers(from: oldDescriptor, to: &newDescriptor)
        guard !Task.isCancelled else { return }

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
        // 取消之前的更新任务
        descriptorUpdateTask?.cancel()
        
        // 1. 在后台准备计算所需的配置（捕获当前的指标类型）
        let calculators = (mainIndicatorTypes + subIndicatorTypes)
            .flatMap { indicator in indicator.makeCalculators() }
        
        // 2. 后台计算新的 valueStorage
        let newValueStorage: ValueStorage
        if calculators.isEmpty {
            newValueStorage = ValueStorage()
        } else {
            newValueStorage = await calculators.calculate(items: items)
            guard !Task.isCancelled else { return }
        }
        
        // 3. 回到主线程，原子性地一次性更新所有状态
        // 此时数据已经准备好，避免中间状态
        klineItems = items
        valueStorage = newValueStorage  // 旧的 valueStorage 引用计数变为 0，ARC 会自动释放
        layout.itemCount = items.count  // 现在可以安全地触发 layoutSubviews
        
        // 4. 调整滚动位置
        scrollView.scroll(to: scrollPosition)
        
        // 5. 更新渲染器描述符（不需要重新计算 valueStorage）
        await updateDescriptor(recalculateValues: false)
    }
    
    private func drawMainIndicator(type: Indicator) async {
        guard !mainIndicatorTypes.contains(type) else { return }
        mainIndicatorTypes.append(type)
        descriptorUpdateTask?.cancel()
        await updateDescriptor(recalculateValues: true)
    }
    
    private func eraseMainIndicator(type: Indicator) {
        guard let index = mainIndicatorTypes.firstIndex(of: type) else { return }
        mainIndicatorTypes.remove(at: index)
        scheduleDescriptorUpdate()
    }
    
    private func drawSubIndicator(type: Indicator) async {
        guard !subIndicatorTypes.contains(type) else { return }
        subIndicatorTypes.append(type)
        descriptorUpdateTask?.cancel()
        await updateDescriptor(recalculateValues: true)
    }
    
    private func eraseSubIndicator(type: Indicator) {
        guard let index = subIndicatorTypes.firstIndex(of: type) else { return }
        subIndicatorTypes.remove(at: index)
        scheduleDescriptorUpdate()
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
        CATransaction.setDisableActions(false)
        CATransaction.setAnimationDuration(0)
        defer { CATransaction.commit() }
        
        let contentRect = scrollView.contentView.bounds
        let visibleRange = layout.visibleRange
        if visibleRange.isEmpty { return }
        
        let context = RendererContext(
            valueStorage: valueStorage,
            items: klineItems,
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

// MARK: - Live Tick Updates
private extension KLineView {
    
    enum LiveUpdateMode {
        case updateExisting  // 更新当前 K 线（同一时间桶）
        case appendNew       // 添加新 K 线（新时间桶）
    }
    
    /// 应用实时行情数据
    func applyLiveTick(_ tick: any KLineItem) {
        guard !klineItems.isEmpty else {
            klineItems = [tick]
            layout.itemCount = 1
            throttleRecalculateAndRedraw()
            return
        }
        
        let mode = determineUpdateMode(for: tick)
        switch mode {
        case .updateExisting:
            animateLastKLine(to: tick, from: .existing(klineItems.last!))
        case .appendNew:
            klineItems.append(tick)
            layout.itemCount = klineItems.count
            animateLastKLine(to: tick, from: .baseline(of: tick))
        }
    }
    
    /// 确定更新模式（是更新现有 K 线还是添加新 K 线）
    private func determineUpdateMode(for tick: any KLineItem) -> LiveUpdateMode {
        guard let last = klineItems.last else { return .appendNew }
        let bucketSeconds = 1
        let isSameBucket = (last.timestamp / bucketSeconds) == (tick.timestamp / bucketSeconds)
        return isSameBucket ? .updateExisting : .appendNew
    }
    
    /// 节流重算和重绘（避免过于频繁的完整重算）
    func throttleRecalculateAndRedraw() {
        let now = CACurrentMediaTime()
        guard now - lastLiveRedrawAt >= 0.2 else { return }
        lastLiveRedrawAt = now
        scheduleDescriptorUpdate(recalculateValues: true)
    }
}

// MARK: - K-Line Animation
private extension KLineView {
    
    enum AnimationStartPoint {
        case existing(any KLineItem)  // 从现有 K 线开始
        case baseline(of: any KLineItem)  // 从基线开始
    }
    
    /// 动画更新最后一根 K 线
    func animateLastKLine(to target: any KLineItem, from startPoint: AnimationStartPoint) {
        guard !klineItems.isEmpty else { return }
        
        ensureAnimatorInitialized()
        
        let lastIndex = klineItems.count - 1
        let fromItem = makeStartItem(from: startPoint)
        let toItem = InterpolatedKLineItem(copying: target)
        
        // 更新数据源
        klineItems[lastIndex] = target
        
        // 对于基线起点，需要先显示基线状态
        if case .baseline = startPoint {
            klineItems[lastIndex] = fromItem
            drawVisibleContent()
        }
        
        // 启动动画
        liveAnimator?.animate(from: fromItem, to: toItem, duration: 0.5)
    }
    
    /// 确保动画器已初始化
    private func ensureAnimatorInitialized() {
        guard liveAnimator == nil else { return }
        
        liveAnimator = Animator()
        liveAnimator?.onFrame = { [weak self] item, _ in
            self?.updateLastKLine(with: item)
        }
        liveAnimator?.onCompletion = { [weak self] finalItem in
            self?.finalizeLastKLine(with: finalItem)
        }
    }
    
    /// 创建动画起始项
    private func makeStartItem(from startPoint: AnimationStartPoint) -> InterpolatedKLineItem {
        switch startPoint {
        case .existing(let item):
            return InterpolatedKLineItem(copying: item)
        case .baseline(let item):
            return InterpolatedKLineItem.makeBaseline(from: item)
        }
    }
    
    /// 更新最后一根 K 线（动画帧回调）
    private func updateLastKLine(with item: InterpolatedKLineItem) {
        guard !klineItems.isEmpty else { return }
        klineItems[klineItems.count - 1] = item
        drawVisibleContent()
    }
    
    /// 完成最后一根 K 线的更新（动画完成回调）
    private func finalizeLastKLine(with finalItem: InterpolatedKLineItem) {
        guard !klineItems.isEmpty else { return }
        klineItems[klineItems.count - 1] = finalItem
        throttleRecalculateAndRedraw()
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
            crosshairRenderer = CrosshairRenderer()
            crosshairRenderer?.install(to: scrollView.contentView.canvas)
        }
        drawVisibleContent()
    }
}

extension KLineView {
    
    private func registerRenderers() {
        registerRenderer(for: .ma) { indicator in
            MARenderer(peroids: indicator.keys.compactMap({ key in
                guard case let .ma(period) = key else { return nil }
                return period
            }))
        }
        registerRenderer(for: .ema) { indicator in
            EMARenderer(peroids: indicator.keys.compactMap({ key in
                guard case let .ema(period) = key else { return nil }
                return period
            }))
        }
        registerRenderer(for: .boll) { _ in
            BOLLRenderer()
        }
        registerRenderer(for: .sar) { _ in
            SARRenderer()
        }
        registerRenderer(for: .vol) { _ in
            VOLRenderer()
        }
        registerRenderer(for: .rsi) { indicator in
            RSIRenderer(peroids: indicator.keys.compactMap({ key in
                guard case let .rsi(period) = key else { return nil }
                return period
            }))
        }
        registerRenderer(for: .macd) { _ in
            MACDRenderer()
        }
    }
    
    public func registerRenderer(for indicator: Indicator, provider: @escaping IndicatorProvider) {
        indiccatorProviderMap[indicator] = provider
    }
}

