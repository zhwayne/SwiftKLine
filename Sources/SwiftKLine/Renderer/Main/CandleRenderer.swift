//
//  CandleRenderer.swift
//  KLineDemo
//
//  Created by iya on 2024/11/1.
//

import UIKit

final class CandleRenderer: Renderer {

    var id: some Hashable { ObjectIdentifier(CandleRenderer.self) }
    private let risingLayer = CAShapeLayer()
    private let fallingLayer = CAShapeLayer()
    
    init() {
        risingLayer.lineWidth = 1
        risingLayer.contentsScale = UIScreen.main.scale
        
        fallingLayer.lineWidth = 1
        fallingLayer.contentsScale = UIScreen.main.scale
    }
    
    func install(to layer: CALayer) {
        layer.addSublayer(risingLayer)
        layer.addSublayer(fallingLayer)
    }
    
    func uninstall(from layer: CALayer) {
        risingLayer.removeFromSuperlayer()
        fallingLayer.removeFromSuperlayer()
    }
    
    func draw(in layer: CALayer, context: Context) {
        // 获取K线样式配置
        let candleStyle = context.configuration.candleStyle
        let layout = context.layout
        let viewPort = context.viewPort
        let visibleItems = context.visibleItems
        let risingColor = KLineTrend.rising.color(using: context.configuration)
        let fallingColor = KLineTrend.falling.color(using: context.configuration)
        risingLayer.fillColor = risingColor.cgColor
        risingLayer.strokeColor = risingColor.cgColor
        fallingLayer.fillColor = fallingColor.cgColor
        fallingLayer.strokeColor = fallingColor.cgColor
        
        let upPath = CGMutablePath()
        let downPath = CGMutablePath()
        let candleHalfWidth = candleStyle.width * 0.5
        let itemWidth = candleStyle.width + candleStyle.gap
        let visibleMinX = CGFloat(context.visibleRange.lowerBound) * itemWidth - layout.scrollView.contentOffset.x
        for (idx, item) in visibleItems.enumerated() {
            // 计算 x 坐标
            let x = CGFloat(idx) * itemWidth + visibleMinX
            
            // 计算开盘价和收盘价的 y 坐标
            let openY = layout.minY(for: item.opening, viewPort: viewPort)
            let closeY = layout.minY(for: item.closing, viewPort: viewPort)
            let y = min(openY, closeY)
            let h = abs(openY - closeY)
            
            let rect = CGRect(x: x, y: y, width: candleStyle.width, height: h)
            
            // 计算最高价和最低价的 y 坐标
            let highY = layout.minY(for: item.highest, viewPort: viewPort)
            let lowY = layout.minY(for: item.lowest, viewPort: viewPort)
            
            let centerX = x + candleHalfWidth
            let highestPoint = CGPoint(x: centerX, y: highY)
            let lowestPoint = CGPoint(x: centerX, y: lowY)
            
            let trend = item.trend
            let candlePath = trend == .falling ? downPath : upPath
            candlePath.addRect(rect)
            candlePath.move(to: highestPoint)
            candlePath.addLine(to: CGPoint(x: centerX, y: y))
            candlePath.move(to: lowestPoint)
            candlePath.addLine(to: CGPoint(x: centerX, y: y + h))
        }
        risingLayer.path = upPath
        fallingLayer.path = downPath
    }
    
    func dataBounds(context: Context) -> MetricBounds {
        return context.visibleItems.dataBounds
    }
}
