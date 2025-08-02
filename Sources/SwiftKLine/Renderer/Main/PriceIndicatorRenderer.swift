//
//  PriceIndicatorRenderer.swift
//  SwiftKLine
//
//  Created by iya on 2025/4/23.
//

import UIKit

final class PriceIndicatorRenderer: Renderer {
        
    var id: some Hashable { ObjectIdentifier(PriceIndicatorRenderer.self) }
    private let style: PriceIndicatorStyle
    
    private let priceLineLayer = CAShapeLayer()
    private let highestTextLayer = CATextLayer()
    private let lowestTextLayer = CATextLayer()
    private let dashLineLayer = CAShapeLayer()
    private let priceMarkView = PriceMarkView()
    private let formatter = PriceFormatter()
    
    init(style: PriceIndicatorStyle) {
        self.style = style
        priceLineLayer.lineWidth = 1
        dashLineLayer.lineWidth = 1 / UIScreen.main.scale
        dashLineLayer.lineDashPattern = [2, 2]
        
        highestTextLayer.font = style.font as CTFont
        highestTextLayer.fontSize = style.font.pointSize
        highestTextLayer.alignmentMode = .center
        highestTextLayer.contentsScale = UIScreen.main.scale
        
        lowestTextLayer.font = style.font as CTFont
        lowestTextLayer.fontSize = style.font.pointSize
        lowestTextLayer.alignmentMode = .center
        lowestTextLayer.contentsScale = UIScreen.main.scale
    }
    
    func install(to layer: CALayer) {
        layer.addSublayer(priceLineLayer)
        layer.addSublayer(highestTextLayer)
        layer.addSublayer(lowestTextLayer)
        layer.addSublayer(dashLineLayer)
        layer.owningView?.addSubview(priceMarkView)
    }
    
    func uninstall(from layer: CALayer) {
        priceLineLayer.removeFromSuperlayer()
        highestTextLayer.removeFromSuperlayer()
        lowestTextLayer.removeFromSuperlayer()
        dashLineLayer.removeFromSuperlayer()
        priceMarkView.removeFromSuperview()
    }
    
    func draw(in layer: CALayer, context: Context) {
        let visibleItems = context.visibleItems
        let layout = context.layout
        let viewPort = context.viewPort
        let candleStyle =  KLineConfig.default.candleStyle
        priceLineLayer.strokeColor = style.textColor.cgColor
        highestTextLayer.foregroundColor = style.textColor.cgColor
        lowestTextLayer.foregroundColor = style.textColor.cgColor
        dashLineLayer.strokeColor = UIColor.label.cgColor
        
        let priceLinePath = CGMutablePath()
        // MARK: - 最高价指示
        if let (idx, item) = visibleItems.upperBoundItem {
            let x = layout.minX(at: idx) + candleStyle.width * 0.5
            let y = layout.minY(for: item.highest, viewPort: viewPort)
            
            let rightSide = (x + viewPort.origin.x) < layer.bounds.midX
            let startPoint = CGPoint(x: x, y: y)
            let endPoint = CGPoint(x: x + (rightSide ? 30 : -30 ), y: y)
            priceLinePath.move(to: startPoint)
            priceLinePath.addLine(to: endPoint)
            
            highestTextLayer.string = formatter.format(item.highest as NSNumber)
            let textSize = highestTextLayer.preferredFrameSize()
            let textOrigin = CGPoint(
                x: endPoint.x + (rightSide ? 0 : -textSize.width),
                y: y - textSize.height * 0.5
            )
            highestTextLayer.frame = CGRect(origin: textOrigin, size: textSize)
        }
        
        // MARK: - 最低价指示
        if let (idx, item) = visibleItems.lowerBoundItem {
            let x = layout.minX(at: idx) + candleStyle.width * 0.5
            let y = layout.minY(for: item.lowest, viewPort: viewPort)
            
            let rightSide = (x + viewPort.origin.x) < layer.bounds.midX
            let startPoint = CGPoint(x: x, y: y)
            let endPoint = CGPoint(x: x + (rightSide ? 30 : -30 ), y: y)
            priceLinePath.move(to: startPoint)
            priceLinePath.addLine(to: endPoint)
            
            lowestTextLayer.string = formatter.format(item.lowest as NSNumber)
            let textSize = lowestTextLayer.preferredFrameSize()
            let textOrigin = CGPoint(
                x: endPoint.x + (rightSide ? 0 : -textSize.width),
                y: y - textSize.height * 0.5
            )
            lowestTextLayer.frame = CGRect(origin: textOrigin, size: textSize)
        }
        
        priceLineLayer.path = priceLinePath
        
        // MARK: - 最新价指示
        if let item = context.items.last {
            let dataBounds = context.visibleItems.dataBounds
            let minY = layout.minY(for: dataBounds.max, viewPort: viewPort)
            let maxY = layout.minY(for: dataBounds.min, viewPort: viewPort)
            let rect = CGRectMake(0, viewPort.minY, layer.bounds.width, viewPort.height)
            var y = layout.minY(for: item.closing, viewPort: viewPort)
            y = min(max(y, minY), maxY)
            let index = context.items.count - context.visibleRange.lowerBound - 1
            var x = layout.minX(at: index)
            if x > rect.maxX { x = 0 }
            let end = CGPoint(x: x, y: y)
            let start = CGPoint(x: rect.width, y: y)
            
            let path = CGMutablePath()
            path.move(to: start)
            path.addLine(to: end)
            dashLineLayer.path = path
            
            priceMarkView.showArrow = end.x == 0
            priceMarkView.label.text = formatter.format(item.closing as NSNumber)
            let indicatorSize = priceMarkView.systemLayoutSizeFitting(rect.size)
            priceMarkView.bounds.size = indicatorSize
            priceMarkView.frame.origin.y = y - indicatorSize.height * 0.5
            priceMarkView.frame.origin.x = start.x - 12 - indicatorSize.width
        }
    }
}
