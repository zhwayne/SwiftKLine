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
    private lazy var layout = Layout(scrollView: scrollView)
    
    // MARK: - Height defines
    private let candleHeight: CGFloat = 340
    private let timelineHeight: CGFloat = 16
    private let indicatorHeight: CGFloat = 72
    private let indicatorTypeHeight: CGFloat = 32
    private var chartHeightConstraint: Constraint!
    
    // MARK: - ChartDescriptor
    private var descriptor = ChartDescriptor()
    
    // MARK: - Data
    private var mainIndicatorTypes: [Indicator] = []
    private var subIndicatorTypes: [Indicator] = []
    private var klineItems: [any KLineItem] = []
    private var valueStorage = ValueStorage()
    private var selectedIndex: Int?
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
            make.width.equalToSuperview().multipliedBy(0.7)
            make.top.equalTo(8)
        }

//        // 添加手势
//        // tap
//        let tap = UITapGestureRecognizer(
//            target: self,
//            action: #selector(Self.handleTap(_:))
//        )
//        tap.cancelsTouchesInView = false
//        tap.delegate = self
//        chartView.addGestureRecognizer(tap)
//        // long press
//        let longPress = UILongPressGestureRecognizer(
//            target: self,
//            action: #selector(Self.handleLongPress(_:))
//        )
//        longPress.minimumPressDuration = 0.25
//        longPress.allowableMovement = 2
//        longPress.cancelsTouchesInView = false
//        longPress.delegate = self
//        chartView.addGestureRecognizer(longPress)
        
        observeScrollViewLayoutChange()
        setupBindings()
        updateDescriptor()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        drawVisibleContent()
    }
    
    public override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        chartHeightConstraint.update(offset: descriptor.height)
        layout.updateContentSize()
    }
    
    public override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.width = max(size.width, bounds.width)
        size.height = descriptor.height + indicatorTypeHeight
        return size
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
            RendererGroup(chartSection: .mainChart, height: candleHeight, padding: (12, 12)) {
                // X轴
                XAxisRenderer()
                //蜡烛图
                CandleRenderer()
                // 主图指标
                for type in mainIndicatorTypes {
                    type.makeRenderer()
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
        let oldDescriptor = descriptor
        let newDescriptor = makeDescriptor()
        
//        let oldRendererSet = Set(oldDescriptor.renderers)
//        let newRendererSet = Set(newDescriptor.renderers)
//        let insertions = newRendererSet.subtracting(oldRendererSet)
//        let deletions = oldRendererSet.subtracting(newRendererSet)
        
        // FIXME: 需要进行 diff 操作
        // 同时还应该把 oldDescriptor 中已存在的 renderer 转移到新的 descriptor 中
        let insertions = newDescriptor.renderers
        let deletions = oldDescriptor.renderers
        
        Task(priority: .userInitiated) {
            // 计算指标数据
            let calculators = (mainIndicatorTypes + subIndicatorTypes).flatMap { indicator in
                return indicator.makeCalculators()
            }
            
            let newValueStorage = await calculators.calculate(items: klineItems)
            
            insertions.forEach { renderer in
                renderer.install(to: scrollView.contentView.canvas)
            }
            deletions.forEach { renderer in
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
            selectedIndex: selectedIndex,
            visibleRange: visibleRange,
            candleStyle: styleManager.candleStyle,
            layout: layout,
            groupFrame: .zero,
            viewPort: .zero
        )
        
        for (idx, group) in descriptor.groups.enumerated() {
            let renderers = group.renderers
            
            // 计算可见区域内每个 group 所在的位置
            let groupFrame = descriptor.frameOfGroup(at: idx, rect: contentRect)
            context.groupFrame = groupFrame
            
            var dataBounds: MetricBounds = .empty
            // 计算可见区域内数据范围
            for renderer in renderers {
                dataBounds.merge(other: renderer.dataBounds(context: context))
            }
            context.layout.dataBounds = dataBounds
            
            // 绘制主图图例（副图图例由 renderer 自行处理）
            var viewPortOffsetY: CGFloat = 0
            if group.chartSection == .mainChart {
                let legendIndex = context.visibleRange.upperBound - 1
                let legendString = NSMutableAttributedString()
                for renderer in renderers {
                    if let string = renderer.legend(at: legendIndex, context: context) {
                        legendString.append(string)
                        legendString.append(NSAttributedString(string: "\n"))
                    }
                }
                legendString.addAttribute(.font, value: styleManager.legendFont, range: NSMakeRange(0, legendString.length))
                legendLabel.attributedText = legendString
                legendLabel.sizeToFit()
                // 计算 viewPort
                let legendFrame = legendLabel.frame
                viewPortOffsetY = legendFrame.height == 0 ? 0 : (legendFrame.maxY - groupFrame.minY)
            }
            
            // 计算 viewPort
            let groupInset = UIEdgeInsets(
                top: group.padding.top + viewPortOffsetY, left: 0,
                bottom: group.padding.bottom, right: 0
            )
            context.viewPort = groupFrame.inset(by: groupInset)

            // 绘制图表
            for renderer in renderers {
                renderer.draw(in: scrollView.contentView.canvas, context: context)
            }
        }
    }
//    
//    /// 绘制主图区域内的所有内容，包括图例，背景，蜡烛图，主图指标。
//    private func drawMainChartSection(
//        in visibleRect: CGRect,
//        range: Range<Int>,
//        indices: Range<Int>
//    ) {
//        let start = CACurrentMediaTime()
//        defer {
//            let end = CACurrentMediaTime()
//            let duration = (end - start) * 1000
//            print("Draw in \(String(format: "%.3f", duration)) ms.")
//        }
//        // 绘制图例。可以考虑将 legend 渲染方式替换成 Renderer。
//        legendLabel.attributedText = legendText(for: mainIndicatorTypes)
//        let legendSize = legendLabel.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
//        var offsetY: CGFloat = 16
//        if legendSize.height > 0 {
//            offsetY = legendLabel.frame.origin.y + legendSize.height + 8
//        }
//        
//        let candleInset = AxisInset(top: offsetY, bottom: 16)
//        let rect = CGRect(
//            x: visibleRect.minX,
//            y: 0,
//            width: visibleRect.width,
//            height: candleHeight
//        )
//        
//        // 获取可见区域内数据的 metricBounds
//        var dataBounds = visibleItems.priceBounds
//        mainRenderers.forEach { renderer in
//            renderer.type.keys.forEach { key in
//                if let indicatorMetricBounds = visibleDatas.bounds(for: key) {
//                    dataBounds.combine(other: indicatorMetricBounds)
//                }
//            }
//        }
//        
//        let transformer = Transformer(
//            axisInset: candleInset,
//            dataBounds: dataBounds,
//            viewPort: rect,
//            itemCount: klineItems.count,
//            visibleRange: range,
//            indices: indices
//        )
//        let itemRenderData = RenderData(
//            items: klineItems,
//            visibleRange: range
//        )
//        let indicatorRenderData = RenderData(
//            items: indicatorDatas as [Any],
//            visibleRange: range
//        )
//        
//        // 蜡烛图背景
//        backgroundRenderer.transformer = transformer
//        backgroundRenderer.draw(in: candleView.canvas, data: itemRenderData)
//        
//        // 蜡烛图
//        candleRenderer.transformer = transformer
//        candleRenderer.draw(in: candleView.canvas, data: itemRenderData)
//        
//        // 主图指标
//        mainRenderers.forEach { renderer in
//            renderer.transformer = transformer
//            renderer.draw(in: candleView.canvas, data: indicatorRenderData)
//        }
//    }
//    
//    /// 绘制时间轴
//    private func drawTimeline(in rect: CGRect, range: Range<Int>, indices: Range<Int>) {
//        // 指标数据在 layer 中的可见区域
//        let viewPort = CGRect(
//            x: rect.minX, y: 0,
//            width: rect.width,
//            height: timelineHeight
//        )
//        // 创建一个新的 transformer
//        let transformer = Transformer(
//            dataBounds: .neutral,
//            viewPort: viewPort,
//            itemCount: klineItems.count,
//            visibleRange: range,
//            indices: indices
//        )
//        // 创建一个新的 RenderData
//        let renderData = RenderData(
//            items: klineItems,
//            visibleRange: range
//        )
//        // 绘制时间轴
//        timelineRenderer.transformer = transformer
//        timelineRenderer.draw(in: timelineView.canvas, data: renderData)
//    }
//    
//    private func drawSubChartSection(in rect: CGRect, range: Range<Int>, indices: Range<Int>) {
//        for (idx, renderer) in subRenderers.enumerated() {
//            // 获取可见区域内数据的 metricBounds
//            var dataBounds = MetricBounds.neutral
//            renderer.type.keys.forEach { key in
//                if let indicatorMetricBounds = visibleDatas.bounds(for: key) {
//                    dataBounds.combine(other: indicatorMetricBounds)
//                }
//            }
//            // 指标数据在 layer 中的可见区域
//            let viewPort = CGRect(
//                x: rect.minX,
//                y: CGFloat(idx) * indicatorHeight,
//                width: rect.width,
//                height: indicatorHeight
//            )
//            // 创建一个新的 transformer
//            let transformer = Transformer(
//                axisInset: AxisInset(top: 26, bottom: 2),
//                dataBounds: dataBounds,
//                viewPort: viewPort,
//                itemCount: indicatorDatas.count,
//                visibleRange: range,
//                indices: indices
//            )
//            // 创建一个新的 RenderData
//            let renderData: RenderData<Any> = RenderData(
//                items: indicatorDatas,
//                visibleRange: range,
//                selectedItem: selectedData
//            )
//            // 绘制指标
//            renderer.transformer = transformer
//            renderer.draw(in: subIndicatorView.canvas, data: renderData)
//        }
//    }
//    
//    private func legendText(for types: [Indicator]) -> NSAttributedString? {
//        let legendText = NSMutableAttributedString()
//        
//        guard let indicatorData = selectedData ?? visibleDatas.last else {
//            return nil
//        }
//        
//        types.enumerated().forEach { idx, type in
//            let text = NSMutableAttributedString()
//            for key in type.keys {
//                var string: String = ""
//                if let value = indicatorData.indicator(forKey: key) as? Double {
//                    string = "\(key):\(styleManager.format(value: value))  "
//                }
//                if let value = indicatorData.indicator(forKey: key) as? Int {
//                    string = "\(key):\(styleManager.format(value: value))  "
//                }
//                if let indicatorStyle = styleManager.indicatorStyle(for: key, type: TrackStyle.self) {
//                    let span = NSAttributedString(
//                        string: string,
//                        attributes: [
//                            .foregroundColor: indicatorStyle.strokeColor,
//                            .font: UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
//                        ]
//                    )
//                    text.append(span)
//                }
//            }
//            if idx != 0 {
//                text.insert(NSAttributedString(string: "\n"), at: 0)
//            }
//            legendText.append(text)
//        }
//        return legendText
//    }
}

extension KLineView {
    
    private func observeScrollViewLayoutChange() {
        scrollView.onLayoutChanged = { [unowned self] scrollView in
            drawVisibleContent()
            klineItemLoader?.scrollViewDidScroll(scrollView: scrollView)
        }
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

