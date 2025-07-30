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
    private lazy var layout = Layout(scrollView: scrollView)
    
    // MARK: - Height defines
    private let candleHeight: CGFloat = 320
    private let timelineHeight: CGFloat = 16
    private let indicatorHeight: CGFloat = 56
    private let indicatorTypeHeight: CGFloat = 32
    private var chartHeightConstraint: Constraint!
    private var viewHeight: CGFloat { descriptor.height + indicatorTypeHeight }
    
    // MARK: - ChartDescriptor
    private var descriptor = ChartDescriptor()
    private var customRenderers = [AnyRenderer]()
    private var crosshairRenderer: CrosshairRenderer?
    
    // MARK: - Data
    private var mainIndicatorTypes: [Indicator] = []
    private var subIndicatorTypes: [Indicator] = []
    private var klineItems: [any KLineItem] = []
    private var valueStorage = ValueStorage()
    private var selectedIndex: Int?
    private var selectedLocation: CGPoint?
    private var styleManager: StyleManager { .shared }
    private var longPressLocation: CGPoint = .zero
    
    private var klineItemLoader: KLineItemLoader?
    private var disposeBag = Set<AnyCancellable>()
    
    // MARK: - Initializers
    public override init(frame: CGRect) {
        super.init(frame: frame)
        chartView.layer.masksToBounds = true
        
        /* 这个地方应该开放接口，让调用方决定启用哪些指标 */
        indicatorTypeView.mainIndicators = [.ma, .ema]
        indicatorTypeView.subIndicators = [.vol, .rsi, .macd]
        
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
                    type.makeRenderer()
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
                    type.makeRenderer()
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
            candleStyle: styleManager.candleStyle,
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
            renderer.group = group
            if let timelineGroup = descriptor.groups.first(where: { $0.chartSection == .timeline }) {
                renderer.timelineGroupFrame = timelineGroup.groupFrame
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
//// MARK: - 手势处理
//extension KLineView: UIGestureRecognizerDelegate {
//    
//    @objc private func handleTap(_ tap: UITapGestureRecognizer) {
//        longPressLocation = tap.location(in: tap.view)
//        drawCrosshair()
//    }
//
//    @objc private func handleLongPress(_ longPress: UILongPressGestureRecognizer) {
//        longPressLocation = longPress.location(in: longPress.view)
//        switch longPress.state {
//        case .began, .changed: drawCrosshair()
//        default: break
//        }
//    }
//    
//    private func drawCrosshair() {
//        // MARK: - 绘制长按图层
//        
//        CATransaction.begin()
//        CATransaction.setDisableActions(false)
//        CATransaction.setAnimationDuration(0)
//        defer {
//            CATransaction.commit()
//        }
//        
//        var location = longPressLocation
//        location.y = min(max(0, location.y), scrollView.contentView.bounds.height - 1)
//        longPressLocation = location
//        
//        var transformer: Transformer?
//        // 判断当前是在哪个区域
//        if candleView.frame.contains(location) {
//            // 主图区域
//            transformer = candleRenderer.transformer
//            crosshairRengerer.locationRect = candleView.frame
//        } else if timelineView.frame.contains(location) {
//            // 时间轴区域
//            transformer = timelineRenderer.transformer
//            crosshairRengerer.locationRect = timelineView.frame
//        } else if !subRenderers.isEmpty {
//            // 计算当前在副图区域的哪个指标上
//            let offsetY = location.y - subIndicatorView.frame.minY
//            let idx = min(Int(floor(offsetY / indicatorHeight)), subRenderers.count - 1)
//            let renderer = subRenderers[idx]
//            transformer = renderer.transformer
//            crosshairRengerer.locationRect = CGRect(
//                x: 0,
//                y: subIndicatorView.frame.minY + CGFloat(idx) * indicatorHeight,
//                width: subIndicatorView.frame.width,
//                height: indicatorHeight
//            )
//        }
//        
//        guard let transformer = transformer else { return }
//        
//        let data = RenderData(
//            items: indicatorDatas,
//            visibleRange: scrollView.visibleRange
//        )
//    
//        chartView.canvas.sublayers = nil
//        crosshairRengerer.location = location
//        crosshairRengerer.timelineHeight = timelineHeight
//        crosshairRengerer.timelineY = timelineView.frame.minY
//        crosshairRengerer.klineItemY = candleRenderer.transformer!.axisInset.top - 4
//        crosshairRengerer.transformer = transformer
//        crosshairRengerer.draw(in: chartView.canvas, data: data)
//    }
//    
//    private func cleanLongPressContetent() {
//        selectedData = nil
//        chartView.canvas.sublayers = nil
//        for view in chartView.subviews where view !== scrollView {
//            view.removeFromSuperview()
//        }
//    }
//    
//    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
//        if touch.view is UIControl {
//            return false
//        }
//        return true
//    }
//}

