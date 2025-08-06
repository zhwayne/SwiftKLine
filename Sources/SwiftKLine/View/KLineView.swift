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
    
    // MARK: - Data
    private var mainIndicatorTypes: [Indicator] = []
    private var subIndicatorTypes: [Indicator] = []
    private var klineItems: [any KLineItem] = []
    private var valueStorage = ValueStorage()
    private var selectedIndex: Int?
    private var selectedLocation: CGPoint?
    private var klineConfig: KLineConfig { .default }
    private var longPressLocation: CGPoint = .zero
    
    private var klineItemLoader: KLineItemLoader?
    private var disposeBag = Set<AnyCancellable>()
    
    // MARK: - Initializers
    public override init(frame: CGRect) {
        super.init(frame: frame)
        chartView.layer.masksToBounds = true
        
        indicatorTypeView.mainIndicators = klineConfig.indicators.filter { $0.isMain }
        indicatorTypeView.subIndicators =  klineConfig.indicators.filter { !$0.isMain }
        
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
        updateDescriptor()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
    }
}

extension KLineView {
    
    public func setProvider(_ provider: some KLineItemProvider) {
        // TODO: 显示 loading
        klineItemLoader = KLineItemLoader(provider: provider) { [weak self] page, items in
            guard let self else { return }
            if page == 0 {
                valueStorage = ValueStorage()
                await draw(items: items, scrollPosition: .right)
            } else {
                let allItems = items + klineItems
                await draw(items: allItems, scrollPosition: .current)
            }
        }
        klineItemLoader?.loadMore()
    }
}

// MARK: - 绘制和擦除指标
extension KLineView {
    
    private func makeDescriptor() -> ChartDescriptor {
        ChartDescriptor {
            // MARK: - 主图
            RendererGroup(chartSection: .mainChart, height: candleHeight, padding: (16, 12)) {
                // X轴
                XAxisRenderer()
                //蜡烛图
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
            // MARK: - Timeline
            RendererGroup(chartSection: .timeline, height: timelineHeight, padding: (0, 0)) {
                TimelineRenderer(style: TimelineStyle())
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
    
    private func updateDescriptor() {
        Task(priority: .userInitiated) {
            let oldDescriptor = descriptor
            let newDescriptor = makeDescriptor()
            let inserted = newDescriptor.renderers
            let deleted = oldDescriptor.renderers
    
            let allTypes = mainIndicatorTypes + subIndicatorTypes
            // 计算指标数据
            let calculators = allTypes.flatMap { indicator in
                return indicator.makeCalculators()
            }
            
            let newValueStorage = await calculators.calculate(items: klineItems)
            
            inserted.forEach { renderer in
                renderer.install(to: scrollView.contentView.canvas)
            }
            deleted.forEach { renderer in
                renderer.uninstall(from: scrollView.contentView.canvas)
            }

            descriptor = newDescriptor
            valueStorage = newValueStorage
            invalidateIntrinsicContentSize()
            drawVisibleContent()
        }
    }
    
    private func draw(items: [any KLineItem], scrollPosition: ScrollPosition) async {
        let calculators = (mainIndicatorTypes + subIndicatorTypes).flatMap { indicator in
            return indicator.makeCalculators()
        }
        let newValueStorage = await calculators.calculate(items: items)
        valueStorage = newValueStorage
        klineItems = items
        layout.itemCount = items.count
        scrollView.scroll(to: scrollPosition)
        updateDescriptor()
        drawVisibleContent()
    }
    
    private func drawMainIndicator(type: Indicator) async {
        mainIndicatorTypes.append(type)
        updateDescriptor()
    }
    
    private func eraseMainIndicator(type: Indicator) {
        mainIndicatorTypes.removeAll(where: { $0 == type })
        updateDescriptor()
    }
    
    private func drawSubIndicator(type: Indicator) async {
        subIndicatorTypes.append(type)
        updateDescriptor()
    }
    
    private func eraseSubIndicator(type: Indicator) {
        subIndicatorTypes.removeAll(where: { $0 == type })
        updateDescriptor()
    }
}

// MARK: - 绘制内容
extension KLineView {
   
    private func drawVisibleContent() {
        guard !klineItems.isEmpty else { return }
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
        scrollView.onLayoutChanged = { [unowned self] scrollView in
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
