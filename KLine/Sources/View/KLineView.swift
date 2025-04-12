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
    case mainChart, subChart
}

@MainActor public final class KLineView: UIView {

    // MARK: - Views
    private let chartView = CanvasView()
    private let scrollView = HorizontalScrollView()
    private let candleView = CanvasView()
    private let legendLabel = UILabel()
    private let timelineView = CanvasView()
    private let subIndicatorView = CanvasView()
    private var indicatorTypeView = IndicatorTypeView()
    private let watermarkLabel = UILabel()
    
    // MARK: - Height defines
    private let candleHeight: CGFloat = 340
    private let timelineHeight: CGFloat = 16
    private let indicatorHeight: CGFloat = 64
    private let indicatorTypeHeight: CGFloat = 32
    private var chartHeightConstraint: Constraint!
    
    // MARK: - Renderers
    private let backgroundRenderer = BackgroundRenderer()
    private let candleRenderer = CandleRenderer()
    private let timelineRenderer = TimelineRenderer()
    private let crosshairRengerer = CrosshairRenderer()
    private var mainRenderers: [AnyIndicatorRenderer] = []
    private var subRenderers: [AnyIndicatorRenderer] = []
    
    // MARK: - Data
    private var mainIndicatorTypes: [IndicatorType] = []
    private var subIndicatorTypes: [IndicatorType] = []
    private var klineItems: [KLineItem] = []
    private var indicatorDatas: [IndicatorData] = []
    private var selectedData: IndicatorData?
    private var calculators: [any IndicatorCalculator] = []
    private var styleManager: StyleManager { .shared }
    private var longPressLocation: CGPoint = .zero
    
    private var disposeBag = Set<AnyCancellable>()
    
    // MARK: - Initializers
    public override init(frame: CGRect) {
        super.init(frame: frame)
        chartView.layer.masksToBounds = true
        chartView.canvas.zPosition = 1
        
        /* 这个地方应该开放接口，让调用方决定启用哪些指标 */
        indicatorTypeView.mainIndicators = [.vol, .ma, .ema]
        indicatorTypeView.subIndicators = [.vol, .rsi, .macd]
        
        scrollView.delegate = self
        candleView.layer.masksToBounds = true
        timelineView.layer.masksToBounds = true
        subIndicatorView.layer.masksToBounds = true
        
        addSubview(chartView)
        addSubview(indicatorTypeView)
        
        watermarkLabel.text = "Created by iyabb"
        watermarkLabel.textColor = .quaternarySystemFill
        watermarkLabel.font = .systemFont(ofSize: 32, weight: .bold)
        candleView.addSubview(watermarkLabel)
        watermarkLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        chartView.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.bottom.equalTo(indicatorTypeView.snp.top)
            chartHeightConstraint = make.height.equalTo(scrollViewHeight).constraint
        }
        indicatorTypeView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(indicatorTypeHeight)
        }
        
        chartView.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        scrollView.contentView.addSubview(candleView)
        candleView.snp.makeConstraints { make in
            make.top.left.width.equalToSuperview()
            make.height.equalTo(candleHeight)
        }
        
        scrollView.contentView.addSubview(timelineView)
        timelineView.snp.makeConstraints { make in
            make.left.width.equalToSuperview()
            make.top.equalTo(candleView.snp.bottom)
            make.height.equalTo(timelineHeight)
        }
        
        scrollView.contentView.addSubview(subIndicatorView)
        subIndicatorView.snp.makeConstraints { make in
            make.left.width.equalToSuperview()
            make.top.equalTo(timelineView.snp.bottom)
            make.bottom.equalToSuperview()
        }
        
        legendLabel.numberOfLines = 0
        scrollView.contentView.addSubview(legendLabel)
        legendLabel.snp.makeConstraints { make in
            make.left.equalTo(12)
            make.width.equalToSuperview().multipliedBy(0.8)
            make.top.equalTo(8)
        }

        // 添加手势
        // tap
        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(Self.handleTap(_:))
        )
        tap.cancelsTouchesInView = false
        tap.delegate = self
        chartView.addGestureRecognizer(tap)
        // long press
        let longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(Self.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.25
        longPress.allowableMovement = 2
        longPress.cancelsTouchesInView = false
        longPress.delegate = self
        chartView.addGestureRecognizer(longPress)
        
        setupBindings()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    
    private var scrollViewHeight: CGFloat {
        let subIndicatorCount = CGFloat(subIndicatorTypes.count)
        return candleHeight + timelineHeight + subIndicatorCount * indicatorHeight
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        drawVisibleContent()
        if let sublayers = chartView.canvas.sublayers, !sublayers.isEmpty {
            drawCrosshair()
        }
    }
   
    private func updateChartHeightConstraint() {
        chartHeightConstraint.update(offset: scrollViewHeight)
        cleanLongPressContetent()
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
                    updateChartHeightConstraint()
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
                updateChartHeightConstraint()
            }
            .store(in: &disposeBag)
        
        NotificationCenter.default.publisher(for: .scrollToTop)
            .sink { [weak self] _ in
                self?.scrollView.scroll(to: .right)
            }
            .store(in: &disposeBag)
        
        NotificationCenter.default.publisher(for: .didSelectKLineItem)
            .receive(on: DispatchQueue.main)
            .compactMap { $0.object as? Int }
            .sink { [weak self] index in
                guard let self else { return }
                selectedData = indicatorDatas[index]
                drawVisibleContent()
            }
            .store(in: &disposeBag)
    }
}

// MARK: - 对外提供的绘制接口
extension KLineView {
    
    public func draw(items: [KLineItem], scrollPosition: ScrollPosition) {
        Task {
            klineItems = items
            scrollView.klineItemCount = items.count
            indicatorDatas = await klineItems.decorateWithIndicators(calculators: calculators)
            redrawContent(scrollPosition: scrollPosition)
        }
    }
    
    private func redrawContent(scrollPosition: ScrollPosition) {
        scrollView.scroll(to: scrollPosition)
        drawVisibleContent()
    }
}

// MARK: - 绘制和擦除指标
extension KLineView {
    
    private func drawMainIndicator(type: IndicatorType) async {
        mainIndicatorTypes.append(type)
        if type != .vol {
            mainRenderers.append(type.renderer)
        }
        let calcs = type.keys.map(\.calculator)
        calculators.append(contentsOf: calcs)
        let datas = await klineItems.decorateWithIndicators(calculators: calcs)
        indicatorDatas.merge(datas)
        redrawContent(scrollPosition: .current)
    }
    
    private func eraseMainIndicator(type: IndicatorType) {
        mainIndicatorTypes.removeAll(where: { $0 == type })
        mainRenderers.removeAll { $0.type == type }
        let keys = type.keys
        calculators.removeAll { keys.contains($0.key) }
        redrawContent(scrollPosition: .current)
    }
    
    private func drawSubIndicator(type: IndicatorType) async {
        subIndicatorTypes.append(type)
        subRenderers.append(type.renderer)
        let calcs = type.keys.map(\.calculator)
        calculators.append(contentsOf: calcs)
        let datas = await klineItems.decorateWithIndicators(calculators: calcs)
        indicatorDatas.merge(datas)
        redrawContent(scrollPosition: .current)
    }
    
    private func eraseSubIndicator(type: IndicatorType) {
        subIndicatorTypes.removeAll(where: { $0 == type })
        subRenderers.removeAll { $0.type == type }
        let keys = type.keys
        calculators.removeAll { keys.contains($0.key) }
        redrawContent(scrollPosition: .current)
    }
}

// MARK: - 绘制内容
extension KLineView {
   
    private var visibleItems: ArraySlice<KLineItem> {
        if klineItems.isEmpty { return [] }
        return klineItems[scrollView.visibleRange]
    }
    
    private var visibleDatas: ArraySlice<IndicatorData> {
        if indicatorDatas.isEmpty { return [] }
        return indicatorDatas[scrollView.visibleRange]
    }
    
    private func drawVisibleContent() {
        let start = CACurrentMediaTime()
        defer {
            let end = CACurrentMediaTime()
            let duration = (end - start) * 1000
            print("draw in \(String(format: "%.3f", duration)) ms.")
        }
        guard !klineItems.isEmpty else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(false)
        CATransaction.setAnimationDuration(0)
        defer {
            CATransaction.commit()
        }
        // 清除绘制内容
        candleView.clean()
        timelineView.clean()
        subIndicatorView.clean()
        
        let visibleRange = scrollView.visibleRange
        let visibleRect = scrollView.frameOfVisibleRangeInConentView
        let indices = scrollView.indices
            
        
        // MARK: - 绘制主图
        drawMainChartSection(
            in: visibleRect,
            range: visibleRange,
            indices: indices
        )
        
        // MARK: - 绘制时间轴
        drawTimeline(
            in: visibleRect,
            range: visibleRange,
            indices: indices
        )
        
        // MARK: - 绘制副图
        drawSubChartSection(
            in: visibleRect,
            range: visibleRange,
            indices: indices
        )
    }
    
    /// 绘制主图区域内的所有内容，包括图例，背景，蜡烛图，主图指标。
    private func drawMainChartSection(
        in visibleRect: CGRect,
        range: Range<Int>,
        indices: Range<Int>
    ) {
        // 绘制图例。可以考虑将 legend 渲染方式替换成 ChartRenderer。
        legendLabel.attributedText = legendText(for: mainIndicatorTypes)
        let legendSize = legendLabel.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        var offsetY: CGFloat = 16
        if legendSize.height > 0 {
            offsetY = legendLabel.frame.origin.y + legendSize.height + 8
        }
        
        let candleInset = AxisInset(top: offsetY, bottom: 16)
        let rect = CGRect(
            x: visibleRect.minX,
            y: 0,
            width: visibleRect.width,
            height: candleHeight
        )
        
        // 获取可见区域内数据的 metricBounds
        var dataBounds = visibleItems.priceBounds
        mainRenderers.forEach { renderer in
            renderer.type.keys.forEach { key in
                if let indicatorMetricBounds = visibleDatas.bounds(for: key) {
                    dataBounds.combine(other: indicatorMetricBounds)
                }
            }
        }
        
        let transformer = Transformer(
            axisInset: candleInset,
            dataBounds: dataBounds,
            viewPort: rect,
            itemCount: klineItems.count,
            visibleRange: range,
            indices: indices
        )
        let itemRenderData = RenderData(
            items: klineItems,
            visibleRange: range
        )
        let indicatorRenderData = RenderData(
            items: indicatorDatas as [Any],
            visibleRange: range
        )
        
        // 蜡烛图背景
        backgroundRenderer.transformer = transformer
        backgroundRenderer.draw(in: candleView.canvas, data: itemRenderData)
        
        // 蜡烛图
        candleRenderer.transformer = transformer
        candleRenderer.draw(in: candleView.canvas, data: itemRenderData)
        
        // 主图指标
        mainRenderers.forEach { renderer in
            renderer.transformer = transformer
            renderer.draw(in: candleView.canvas, data: indicatorRenderData)
        }
    }
    
    /// 绘制时间轴
    private func drawTimeline(in rect: CGRect, range: Range<Int>, indices: Range<Int>) {
        // 指标数据在 layer 中的可见区域
        let viewPort = CGRect(
            x: rect.minX, y: 0,
            width: rect.width,
            height: timelineHeight
        )
        // 创建一个新的 transformer
        let transformer = Transformer(
            dataBounds: .zero,
            viewPort: viewPort,
            itemCount: klineItems.count,
            visibleRange: range,
            indices: indices
        )
        // 创建一个新的 RenderData
        let renderData = RenderData(
            items: klineItems,
            visibleRange: range
        )
        // 绘制时间轴
        timelineRenderer.transformer = transformer
        timelineRenderer.draw(in: timelineView.canvas, data: renderData)
    }
    
    private func drawSubChartSection(in rect: CGRect, range: Range<Int>, indices: Range<Int>) {
        for (idx, renderer) in subRenderers.enumerated() {
            // 获取可见区域内数据的 metricBounds
            var dataBounds = MetricBounds.zero
            renderer.type.keys.forEach { key in
                if let indicatorMetricBounds = visibleDatas.bounds(for: key) {
                    dataBounds.combine(other: indicatorMetricBounds)
                }
            }
            // 指标数据在 layer 中的可见区域
            let viewPort = CGRect(
                x: rect.minX,
                y: CGFloat(idx) * indicatorHeight,
                width: rect.width,
                height: indicatorHeight
            )
            // 创建一个新的 transformer
            let transformer = Transformer(
                axisInset: AxisInset(top: 26, bottom: 2),
                dataBounds: dataBounds,
                viewPort: viewPort,
                itemCount: indicatorDatas.count,
                visibleRange: range,
                indices: indices
            )
            // 创建一个新的 RenderData
            let renderData: RenderData<Any> = RenderData(
                items: indicatorDatas,
                visibleRange: range,
                selectedItem: selectedData
            )
            // 绘制指标
            renderer.transformer = transformer
            renderer.draw(in: subIndicatorView.canvas, data: renderData)
        }
    }
    
    private func legendText(for types: [IndicatorType]) -> NSAttributedString? {
        let legendText = NSMutableAttributedString()
        
        guard let indicatorData = selectedData ?? visibleDatas.last else {
            return nil
        }
        
        types.enumerated().forEach { idx, type in
            let text = NSMutableAttributedString()
            for key in type.keys {
                var string: String = ""
                if let value = indicatorData.indicator(forKey: key) as? Double {
                    string = "\(key):\(styleManager.format(value: value))  "
                }
                if let value = indicatorData.indicator(forKey: key) as? Int {
                    string = "\(key):\(styleManager.format(value: value))  "
                }
                let indicatorStyle = styleManager.indicatorStyle(for: key)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineHeightMultiple = 1.1
                let span = NSAttributedString(
                    string: string,
                    attributes: [
                        .foregroundColor: indicatorStyle.strokeColor,
                        .font: indicatorStyle.font,
                        .paragraphStyle: paragraphStyle
                    ]
                )
                text.append(span)
            }
            if idx != 0 {
                text.insert(NSAttributedString(string: "\n"), at: 0)
            }
            legendText.append(text)
        }
        return legendText
    }
}

extension KLineView: UIScrollViewDelegate {
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === self.scrollView {
            drawVisibleContent()
            cleanLongPressContetent()
        }
    }
}

// MARK: - 手势处理
extension KLineView: UIGestureRecognizerDelegate {
    
    @objc private func handleTap(_ tap: UITapGestureRecognizer) {
        longPressLocation = tap.location(in: tap.view)
        drawCrosshair()
    }

    @objc private func handleLongPress(_ longPress: UILongPressGestureRecognizer) {
        longPressLocation = longPress.location(in: longPress.view)
        switch longPress.state {
        case .began, .changed: drawCrosshair()
        default: break
        }
    }
    
    private func drawCrosshair() {
        // MARK: - 绘制长按图层
        
        CATransaction.begin()
        CATransaction.setDisableActions(false)
        CATransaction.setAnimationDuration(0)
        defer {
            CATransaction.commit()
        }
        
        var location = longPressLocation
        location.y = min(max(0, location.y), scrollView.contentView.bounds.height - 1)
        longPressLocation = location
        
        var transformer: Transformer?
        // 判断当前是在哪个区域
        if candleView.frame.contains(location) {
            // 主图区域
            transformer = candleRenderer.transformer
            crosshairRengerer.locationRect = candleView.frame
        } else if timelineView.frame.contains(location) {
            // 时间轴区域
            transformer = timelineRenderer.transformer
            crosshairRengerer.locationRect = timelineView.frame
        } else if !subRenderers.isEmpty {
            // 计算当前在副图区域的哪个指标上
            let offsetY = location.y - subIndicatorView.frame.minY
            let idx = min(Int(floor(offsetY / indicatorHeight)), subRenderers.count - 1)
            let renderer = subRenderers[idx]
            transformer = renderer.transformer
            crosshairRengerer.locationRect = CGRect(
                x: 0,
                y: subIndicatorView.frame.minY + CGFloat(idx) * indicatorHeight,
                width: subIndicatorView.frame.width,
                height: indicatorHeight
            )
        }
        
        guard let transformer = transformer else { return }
        
        let data = RenderData(
            items: indicatorDatas,
            visibleRange: scrollView.visibleRange
        )
    
        chartView.canvas.sublayers = nil
        crosshairRengerer.location = location
        crosshairRengerer.timelineHeight = timelineHeight
        crosshairRengerer.timelineY = timelineView.frame.minY
        crosshairRengerer.klineItemY = candleRenderer.transformer!.axisInset.top - 4
        crosshairRengerer.transformer = transformer
        crosshairRengerer.draw(in: chartView.canvas, data: data)
    }
    
    private func cleanLongPressContetent() {
        selectedData = nil
        chartView.canvas.sublayers = nil
        for view in chartView.subviews where view !== scrollView {
            view.removeFromSuperview()
        }
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIControl {
            return false
        }
        return true
    }
}
