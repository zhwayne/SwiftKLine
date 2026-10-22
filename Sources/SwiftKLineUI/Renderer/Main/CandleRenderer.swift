//
//  CandleRenderer.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2024/11/01.
//

import SwiftKLineCore
import UIKit

/// Draws visible candle bodies and wicks using reusable rising and falling shape layers.
final class CandleRenderer: ChartRenderer {

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
        let candleDims = context.candleDimensions
        let layout = context.layout
        let viewPort = context.viewPort
        let visibleItems = context.visibleItems
        let risingColor = Trend.rising.color(using: context.appearance)
        let fallingColor = Trend.falling.color(using: context.appearance)
        risingLayer.fillColor = risingColor.cgColor
        risingLayer.strokeColor = risingColor.cgColor
        fallingLayer.fillColor = fallingColor.cgColor
        fallingLayer.strokeColor = fallingColor.cgColor
        
        let upPath = CGMutablePath()
        let downPath = CGMutablePath()
        let candleHalfWidth = candleDims.width * 0.5
        let itemWidth = candleDims.itemWidth
        let visibleMinX = CGFloat(context.visibleRange.lowerBound) * itemWidth - layout.scrollView.contentOffset.x
        for (idx, item) in visibleItems.enumerated() {
            // Position the candle or bar on the shared horizontal scale.
            let x = CGFloat(idx) * itemWidth + visibleMinX
            
            // Map open and close prices to body endpoints.
            let openY = layout.yPosition(for: item.open, viewPort: viewPort)
            let closeY = layout.yPosition(for: item.close, viewPort: viewPort)
            let y = min(openY, closeY)
            let h = abs(openY - closeY)
            
            let rect = CGRect(x: x, y: y, width: candleDims.width, height: h)
            
            // Map high and low prices to wick endpoints.
            let highY = layout.yPosition(for: item.high, viewPort: viewPort)
            let lowY = layout.yPosition(for: item.low, viewPort: viewPort)
            
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
    
    func dataBounds(context: Context) -> ValueBounds {
        return context.visibleItems.dataBounds
    }
}
