//
//  CandleRenderer.swift
//  KLineDemo
//
//  Created by iya on 2024/11/1.
//

import UIKit

final class CandleRenderer: Renderer {
    typealias Calculator = NothingCalculator

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
        let candleStyle = context.candleStyle
        let layout = context.layout
        let viewPort = context.viewPort
        let visibleItems = context.visibleItems
        risingLayer.fillColor = KLineTrend.rising.color
        risingLayer.strokeColor = KLineTrend.rising.color
        fallingLayer.fillColor = KLineTrend.falling.color
        fallingLayer.strokeColor = KLineTrend.falling.color
        
        let upPath = CGMutablePath()
        let downPath = CGMutablePath()
        for (idx, item) in visibleItems.enumerated() {
            // 计算 x 坐标
            let x = context.layout.minX(at: idx)
            
            // 计算开盘价和收盘价的 y 坐标
            let openY = layout.minY(for: item.opening, viewPort: viewPort)
            let closeY = layout.minY(for: item.closing, viewPort: viewPort)
            let y = min(openY, closeY)
            let h = abs(openY - closeY)
            
            let rect = CGRect(x: x, y: y, width: candleStyle.width, height: h)
            let path = CGMutablePath()
            path.addRect(rect)
            
            // 计算最高价和最低价的 y 坐标
            let highY = layout.minY(for: item.highest, viewPort: viewPort)
            let lowY = layout.minY(for: item.lowest, viewPort: viewPort)
            
            let centerX = candleStyle.width / 2 + x
            let highestPoint = CGPoint(x: centerX, y: highY)
            let lowestPoint = CGPoint(x: centerX, y: lowY)
            
            path.move(to: highestPoint)
            path.addLine(to: CGPoint(x: centerX, y: y))
            path.move(to: lowestPoint)
            path.addLine(to: CGPoint(x: centerX, y: y + h))
            
            let trend = item.trend
            let candlePath = trend == .falling ? downPath : upPath
            candlePath.addPath(path)
        }
        risingLayer.path = upPath
        fallingLayer.path = downPath
    }
    
    func dataBounds(context: Context) -> MetricBounds {
        return context.visibleItems.dataBounds
    }
}
