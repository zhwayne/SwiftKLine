//
//  CrosshairRenderer.swift
//  KLine
//
//  Created by iya on 2025/3/28.
//

import UIKit

final class CrosshairRenderer: Renderer {
    
    var id: some Hashable { ObjectIdentifier(CrosshairRenderer.self) }
    private let dashLineLayer = CAShapeLayer()
    
    var drawableRect: CGRect = .zero
    
    init() {
        dashLineLayer.lineWidth = 1 / UIScreen.main.scale
        dashLineLayer.lineDashPattern = [2, 2]
        dashLineLayer.strokeColor = UIColor.label.cgColor
        dashLineLayer.zPosition = 1
    }
    
    func install(to layer: CALayer) {
        layer.addSublayer(dashLineLayer)
    }
    
    func uninstall(from layer: CALayer) {
        dashLineLayer.removeFromSuperlayer()
    }
    
    func draw(in layer: CALayer, context: Context) {
        guard let location = context.location else { return }
        // MARK: - 绘制y轴虚线
        let path = UIBezierPath()
        path.move(to: CGPoint(x: location.x, y: 0))
        path.addLine(to: CGPoint(x: location.x, y: context.groupFrame.maxY))
        
        // MARK: - 绘制x轴虚线x
        if drawableRect.contains(location) {
            path.move(to: CGPoint(x: 0, y: location.y))
            path.addLine(to: CGPoint(x: layer.bounds.width, y: location.y))
        }
        
        dashLineLayer.path = path.cgPath
    }
}
//
//    private let feedback = UISelectionFeedbackGenerator()
//    private var styleManager: StyleManager { .shared }
//    private let dateFormatter: DateFormatter
//    private let dateLabel = EdgeInsetLabel()
//    private let yAxisValueLabel = EdgeInsetLabel()
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
//        let candleHalfWidth = styleManager.candleStyle.width * 0.5
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
//            yAxisValueLabel.text = styleManager.format(value: value)
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
