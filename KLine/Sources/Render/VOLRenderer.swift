//
//  VOLRenderer.swift
//  KLineDemo
//
//  Created by iya on 2025/3/24.
//

import UIKit

final class VOLRenderer: IndicatorRenderer {
    
    private var styleManager: StyleManager { .shared }
    private let lineWidth = 1 / UIScreen.main.scale
    
    var transformer: Transformer?
    
    typealias Item = IndicatorData
    
    var type: IndicatorType { .vol }
    
    init() {
    }

    func draw(in layer: CALayer, data: RenderData<Item>) {
        guard let transformer = transformer else {
            return
        }
        let rect = transformer.viewPort
        let candleStyle = styleManager.candleStyle
        let items = data.visibleItems
        
        let sublayer = CALayer()
        sublayer.contentsScale = UIScreen.main.scale
        sublayer.frame = rect
        layer.addSublayer(sublayer)
        
        let risingLayer = CAShapeLayer()
        risingLayer.lineWidth = 1
        risingLayer.contentsScale = UIScreen.main.scale
        risingLayer.fillColor = KLineTrend.rising.color
        risingLayer.strokeColor = KLineTrend.rising.color
        risingLayer.opacity = 0.5
        sublayer.addSublayer(risingLayer)
        
        let fallingLayer = CAShapeLayer()
        fallingLayer.lineWidth = 1
        fallingLayer.contentsScale = UIScreen.main.scale
        fallingLayer.fillColor = KLineTrend.falling.color
        fallingLayer.strokeColor = KLineTrend.falling.color
        fallingLayer.opacity = 0.5
        sublayer.addSublayer(fallingLayer)
        
        // MARK: - 网格线（列）
        drawColumnBackground(in: layer, viewPort: transformer.viewPort)
        
        // MARK: - 标题
        let legendLayer = CATextLayer()
        legendLayer.contentsScale = UIScreen.main.scale
        legendLayer.alignmentMode = .left
        legendLayer.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular) as CTFont
        legendLayer.fontSize = 10
        legendLayer.foregroundColor = UIColor.label.withAlphaComponent(0.8).cgColor
        let volume = data.selectedItem?.item.volume ?? items.last!.item.volume
        legendLayer.string = "VOL:\(styleManager.format(value: volume))"
        let size = legendLayer.preferredFrameSize()
        legendLayer.frame = CGRect(x: 12, y: rect.minY + 8, width: size.width, height: size.height)
        layer.addSublayer(legendLayer)
                
        // MARK: - 折线图
        let upPath = UIBezierPath()
        let downPath = UIBezierPath()
        for (idx, item) in items.enumerated() {
            // 计算 x 坐标
            let x = transformer.xAxis(at: idx)
            let y = transformer.yAxis(for: Double(item.item.volume))
            let height = max(rect.height - y - 2, 0)
            let rect = CGRect(x: x, y: y, width: candleStyle.width, height: height)
            let path = UIBezierPath(rect: rect)
            let trend = item.item.trend
            let candlePath = trend == .falling ? downPath : upPath
            candlePath.append(path)
        }
        risingLayer.path = upPath.cgPath
        fallingLayer.path = downPath.cgPath
                
        // MARK: - 边界线
        
        let bottomLineLayer = CAShapeLayer()
        bottomLineLayer.lineWidth = lineWidth
        bottomLineLayer.fillColor = UIColor.clear.cgColor
        bottomLineLayer.strokeColor = UIColor.separator.cgColor
        let bottomLinePath = UIBezierPath()
        bottomLinePath.move(to: CGPoint(x: 0, y: rect.maxY - lineWidth))
        bottomLinePath.addLine(to: CGPoint(x: layer.bounds.maxX, y: rect.maxY - lineWidth))
        bottomLineLayer.path = bottomLinePath.cgPath
        layer.addSublayer(bottomLineLayer)
    }
}
