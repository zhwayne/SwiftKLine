//
//  CrosshairRenderer.swift
//  SwiftKLine
//
//  Created by iya on 2025/3/28.
//

import UIKit

final class CrosshairRenderer: Renderer {
    
    var id: some Hashable { ObjectIdentifier(CrosshairRenderer.self) }
    
    private var klineConfig: KLineConfiguration { .default }
    private let feedback = UISelectionFeedbackGenerator()
    private let dateFormatter: DateFormatter
    private let yValueFormatter: NumberFormatter
    private var lastLocation: CGPoint = .zero
    private let dashLineLayer = CAShapeLayer()
    private let pointLayer = CAShapeLayer()
    private let klineMarkView = KLineMarkView()
    private let dateLabel = PaddedLabel()
    private let yAxisValueLabel = PaddedLabel()
    
    var selectedGroup: RendererGroup?
    var candleGroup: RendererGroup?
    var timelineGroup: RendererGroup?
        
    init() {
        dashLineLayer.lineWidth = 1 / UIScreen.main.scale
        dashLineLayer.lineDashPattern = [2, 2]
        dashLineLayer.strokeColor = UIColor.label.cgColor
        dashLineLayer.zPosition = 1
        pointLayer.fillColor = UIColor.label.cgColor
        
        dateLabel.edgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        dateLabel.backgroundColor = .label
        dateLabel.textColor = .systemBackground
        dateLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        dateLabel.textAlignment = .center
        dateLabel.layer.masksToBounds = true
        dateLabel.layer.cornerRadius = 3
        
        yAxisValueLabel.edgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        yAxisValueLabel.backgroundColor = .label
        yAxisValueLabel.textColor = .systemBackground
        yAxisValueLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        yAxisValueLabel.textAlignment = .center
        yAxisValueLabel.layer.masksToBounds = true
        yAxisValueLabel.layer.cornerRadius = 3
        
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
        
        yValueFormatter = NumberFormatter()
        yValueFormatter.minimumFractionDigits = 2
        yValueFormatter.maximumFractionDigits = 2
        yValueFormatter.numberStyle = .decimal
    }
    
    func install(to layer: CALayer) {
        layer.addSublayer(dashLineLayer)
        layer.addSublayer(pointLayer)
        layer.owningView?.addSubview(klineMarkView)
        layer.owningView?.addSubview(dateLabel)
        layer.owningView?.addSubview(yAxisValueLabel)
    }
    
    func uninstall(from layer: CALayer) {
        dashLineLayer.removeFromSuperlayer()
        pointLayer.removeFromSuperlayer()
        klineMarkView.removeFromSuperview()
        dateLabel.removeFromSuperview()
        yAxisValueLabel.removeFromSuperview()
    }
    
    func draw(in layer: CALayer, context: Context) {
        guard let location = context.location,
              let selectedGroup,
              let candleGroup,
              let timelineGroup else {
            return
        }
        defer { lastLocation = location }
        if lastLocation.x != location.x {
            feedback.selectionChanged()
        }
        // MARK: - 绘制y轴虚线
        let path = UIBezierPath()
        path.move(to: CGPoint(x: location.x, y: 0))
        path.addLine(to: CGPoint(x: location.x, y: layer.bounds.maxY))
        
        // MARK: - 绘制x轴虚线x
        if selectedGroup.chartSection != .timeline/*, group.viewPort.contains(location)*/ {
            path.move(to: CGPoint(x: 0, y: location.y))
            path.addLine(to: CGPoint(x: layer.bounds.width, y: location.y))
        }
        dashLineLayer.path = path.cgPath
        
        // MARK: - 绘制圆点
        let circlePath = UIBezierPath(
            arcCenter: location,
            radius: 2,
            startAngle: 0,
            endAngle: CGFloat.pi * 2,
            clockwise: false
        )
        pointLayer.path = circlePath.cgPath
        
        if let index = context.layout.indexInViewPort(on: location.x) {
            let item = context.items[index]
            
            // MARK: - 绘制 mark view
            klineMarkView.item = item
            let rightSide = location.x < context.groupFrame.midX - 16
            let markSize = klineMarkView.systemLayoutSizeFitting(candleGroup.groupFrame.size)
            let markX = rightSide ? candleGroup.groupFrame.width - 88 - markSize.width : 12
            let markY: CGFloat = candleGroup.viewPort.minY - candleGroup.padding.top * 0.5
            klineMarkView.frame = CGRect(
                x: markX,
                y: markY,
                width: markSize.width,
                height: markSize.height
            )
            
            // MARK: - 绘制日期时间轴
            let date = Date(timeIntervalSince1970: TimeInterval(item.timestamp))
            let timeString = dateFormatter.string(from: date)
            dateLabel.text = timeString
            let dateSize = dateLabel.systemLayoutSizeFitting(timelineGroup.groupFrame.size)
            let dateX = location.x - dateSize.width * 0.5
            let dateY = timelineGroup.groupFrame.minY
            let dateRect = CGRect(
                x: max(0, min(dateX, timelineGroup.groupFrame.width - dateSize.width)),
                y: dateY,
                width: dateSize.width,
                height: timelineGroup.groupFrame.height
            )
            dateLabel.frame = dateRect
        }
        
        // MARK: - 绘制group当前坐标对应的y轴值
        if selectedGroup.chartSection != .timeline {
            let yValue = context.layout.value(on: location.y, viewPort: selectedGroup.viewPort)
            yAxisValueLabel.text = yValueFormatter.string(from: NSDecimalNumber(floatLiteral: yValue))
            let yAxisValueSize = yAxisValueLabel.systemLayoutSizeFitting(selectedGroup.groupFrame.size)
            yAxisValueLabel.frame = CGRect(
                x: selectedGroup.groupFrame.width - yAxisValueSize.width - 12,
                y: location.y - yAxisValueSize.height * 0.5,
                width: yAxisValueSize.width,
                height: yAxisValueSize.height
            )
        } else {
            yAxisValueLabel.text = nil
            yAxisValueLabel.frame = .zero
        }
    }
}
//
//    private let feedback = UISelectionFeedbackGenerator()
//    private var klineConfig: klineConfig { .shared }
//    private let dateFormatter: DateFormatter
//    private let dateLabel = PaddedLabel()
//    private let yAxisValueLabel = PaddedLabel()
//    private let klineMarkView = KLineMarkView()
//    private var lastLocationX: CGFloat = 0
//    var location: CGPoint = .zero
//    var locationRect: CGRect = .zero
//    var transformer: Transformer?
//    var klineItemY: CGFloat = 0
//    var timelineY: CGFloat = 0
//    var timelineHeight: CGFloat = 0
//
//    typealias Item = IndicatorData
//
//    init() {
//        dateLabel.edgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
//        dateLabel.backgroundColor = .label
//        dateLabel.textColor = .systemBackground
//        dateLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
//        dateLabel.textAlignment = .center
//        dateLabel.layer.masksToBounds = true
//        dateLabel.layer.cornerRadius = 3
//        dateLabel.layer.zPosition = 1
//
//        yAxisValueLabel.edgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
//        yAxisValueLabel.backgroundColor = .label
//        yAxisValueLabel.textColor = .systemBackground
//        yAxisValueLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
//        yAxisValueLabel.textAlignment = .center
//        yAxisValueLabel.layer.masksToBounds = true
//        yAxisValueLabel.layer.cornerRadius = 3
//        yAxisValueLabel.layer.zPosition = 1
//
//        klineMarkView.layer.zPosition = 1
//
//        dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
//
//        feedback.prepare()
//    }
//
//    func draw(in layer: CALayer, data: RenderData<Item>) {
//        guard let transformer = transformer else { return }
//
//        let dashLineLayer = CAShapeLayer()
//        dashLineLayer.lineWidth = 1 / UIScreen.main.scale
//        dashLineLayer.lineDashPattern = [2, 2]
//        dashLineLayer.strokeColor = UIColor.label.cgColor
//        dashLineLayer.zPosition = 1
//        layer.addSublayer(dashLineLayer)
//
//        let pointLayer = CAShapeLayer()
//        pointLayer.fillColor = UIColor.label.cgColor
//        layer.addSublayer(pointLayer)
//
//        if let view = layer.owningView {
//            if dateLabel.superview == nil { view.addSubview(dateLabel) }
//            if yAxisValueLabel.superview == nil { view.addSubview(yAxisValueLabel) }
//            if klineMarkView.superview == nil { view.addSubview(klineMarkView) }
//        }
//
//        let rect = layer.bounds
//
//        // 调整x轴，使其始终和蜡烛图item居中对齐
//        let index = transformer.indexOfVisibleItem(xAxis: location.x, extend: true)!
//        let candleHalfWidth = klineConfig.candleStyle.width * 0.5
//        let indexInVisibaleRect = index - data.visibleRange.lowerBound
//        location.x = transformer.xAxis(at: indexInVisibaleRect, space: .layer) + candleHalfWidth
//        // x轴变化时反馈
//        if lastLocationX != location.x {
//            if #available(iOS 17.5, *) {
//                feedback.selectionChanged(at: location)
//            } else {
//                // Fallback on earlier versions
//                feedback.selectionChanged()
//            }
//            if index >= 0 && index < data.items.count {
//                NotificationCenter.default.post(name: .didSelectKLineItem, object: index)
//            }
//        }
//        lastLocationX = location.x
//
//        // MARK: - 绘制y轴虚线
//        let path = UIBezierPath()
//        path.move(to: CGPoint(x: location.x, y: 0))
//        path.addLine(to: CGPoint(x: location.x, y: rect.height))
//        defer { dashLineLayer.path = path.cgPath }
//
//        let edgeInset = UIEdgeInsets(
//            top: transformer.axisInset.top,
//            left: 0,
//            bottom: transformer.axisInset.bottom,
//            right: 0
//        )
//
//        // MARK: - 绘制x轴虚线x
//        let inMainChart = location.y > 0 && locationRect.minY < timelineY
//        let inSubChart = locationRect.minY >= timelineY + timelineHeight
//        && locationRect.inset(by: edgeInset).contains(location)
//        if (inMainChart || inSubChart) {
//            path.move(to: CGPoint(x: 0, y: location.y))
//            path.addLine(to: CGPoint(x: rect.width, y: location.y))
//
//            // MARK: - 绘制圆点
//            let circlePath = UIBezierPath(
//                arcCenter: location,
//                radius: 2,
//                startAngle: 0,
//                endAngle: CGFloat.pi * 2,
//                clockwise: false
//            )
//            pointLayer.path = circlePath.cgPath
//
//            yAxisValueLabel.isHidden = false
//            let value = transformer.valueOf(yAxis: location.y - locationRect.minY)
//
//            yAxisValueLabel.text = klineConfig.format(value: value)
//            let size = yAxisValueLabel.systemLayoutSizeFitting(rect.size)
//            yAxisValueLabel.frame = CGRect(
//                x: rect.width - size.width - 12,
//                y: location.y - size.height * 0.5,
//                width: size.width,
//                height: size.height
//            )
//        } else {
//            yAxisValueLabel.isHidden = true
//        }
//
//        if index >= 0 && index < data.items.count {
//            // MARK: - 绘制日期时间轴
//            dateLabel.isHidden = false
//            let item = data.items[index].item
//            let date = Date(timeIntervalSince1970: TimeInterval(item.timestamp))
//            let timeString = dateFormatter.string(from: date)
//            dateLabel.text = timeString
//            let dateSize = dateLabel.systemLayoutSizeFitting(rect.size)
//            let dateX = location.x - dateSize.width * 0.5
//            let dateRect = CGRect(
//                x: max(0, min(dateX, rect.width - dateSize.width)),
//                y: timelineY,
//                width: dateSize.width,
//                height: timelineHeight
//            )
//            dateLabel.frame = dateRect
//
//            // MARK: - Kline 详情
//            klineMarkView.isHidden = false
//            klineMarkView.item = data.items[index].item
//            let rightSide = location.x < layer.bounds.midX
//            let klineSize = klineMarkView.systemLayoutSizeFitting(rect.size)
//            let klineX = rightSide ? rect.width * 4 / 5 - klineSize.width : 12
//            let klineY = klineItemY
//            let klineRect = CGRect(x: klineX, y: klineY, width: klineSize.width, height: klineSize.height)
//            klineMarkView.frame = klineRect
//        } else {
//            klineMarkView.isHidden = true
//            // FIXME: 根据K线周期计算当前x轴的日期
//            dateLabel.text = nil
//            dateLabel.isHidden = true
//        }
//    }
//}
