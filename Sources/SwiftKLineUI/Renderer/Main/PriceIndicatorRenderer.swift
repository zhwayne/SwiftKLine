//
//  PriceIndicatorRenderer.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2025/04/22.
//

import SwiftKLineCore
import UIKit

/// Annotates visible high/low extremes and the latest price, with a chart-scoped control to follow the latest edge.
final class PriceIndicatorRenderer: ChartRenderer {
        
    private struct ID: Hashable {
        let showsExtremes: Bool
        let latestPointColor: UIColor?
    }
    var id: some Hashable { ID(showsExtremes: showsExtremes, latestPointColor: latestPointColor) }
    private let style: PriceIndicatorStyle
    private let showsExtremes: Bool
    private let latestPointColor: UIColor?
    
    private let priceLineLayer = CAShapeLayer()
    private let highestTextLayer = CATextLayer()
    private let lowestTextLayer = CATextLayer()
    private let latestPointLayer = CAShapeLayer()
    private let dashLineLayer = CAShapeLayer()
    private let priceMarkView = PriceMarkView()
    private let formatter = PriceFormatter()
    
    init(style: PriceIndicatorStyle, showsExtremes: Bool = true, latestPointColor: UIColor? = nil) {
        self.style = style
        self.showsExtremes = showsExtremes
        self.latestPointColor = latestPointColor
        latestPointLayer.name = "latestPricePoint"
        latestPointLayer.fillColor = latestPointColor?.cgColor
        latestPointLayer.strokeColor = nil
        latestPointLayer.zPosition = 3
        dashLineLayer.name = "latestPriceGuide"
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
        layer.addSublayer(latestPointLayer)
        layer.addSublayer(dashLineLayer)
        layer.owningView?.addSubview(priceMarkView)
    }
    
    func uninstall(from layer: CALayer) {
        priceLineLayer.removeFromSuperlayer()
        highestTextLayer.removeFromSuperlayer()
        lowestTextLayer.removeFromSuperlayer()
        latestPointLayer.removeFromSuperlayer()
        dashLineLayer.removeFromSuperlayer()
        priceMarkView.removeFromSuperview()
    }
    
    func draw(in layer: CALayer, context: Context) {
        let visibleItems = context.visibleItems
        let layout = context.layout
        let viewPort = context.viewPort
        let candleDims = context.candleDimensions
        priceLineLayer.strokeColor = style.textColor.cgColor
        highestTextLayer.foregroundColor = style.textColor.cgColor
        lowestTextLayer.foregroundColor = style.textColor.cgColor
        dashLineLayer.strokeColor = UIColor.label.cgColor
        latestPointLayer.fillColor = latestPointColor?.cgColor
        latestPointLayer.path = nil
        
        let priceLinePath = CGMutablePath()
        // MARK: - Visible high marker
        if showsExtremes, let (idx, item) = visibleItems.upperBoundItem {
            let x = layout.xPosition(at: idx) + candleDims.width * 0.5
            let y = layout.yPosition(for: item.high, viewPort: viewPort)
            
            let rightSide = (x + viewPort.origin.x) < layer.bounds.midX
            let startPoint = CGPoint(x: x, y: y)
            let endPoint = CGPoint(x: x + (rightSide ? 30 : -30 ), y: y)
            priceLinePath.move(to: startPoint)
            priceLinePath.addLine(to: endPoint)
            
            highestTextLayer.string = formatter.format(item.high as NSNumber)
            let textSize = highestTextLayer.preferredFrameSize()
            let textOrigin = CGPoint(
                x: endPoint.x + (rightSide ? 0 : -textSize.width),
                y: y - textSize.height * 0.5
            )
            highestTextLayer.frame = CGRect(origin: textOrigin, size: textSize)
        }
        
        // MARK: - Visible low marker
        if showsExtremes, let (idx, item) = visibleItems.lowerBoundItem {
            let x = layout.xPosition(at: idx) + candleDims.width * 0.5
            let y = layout.yPosition(for: item.low, viewPort: viewPort)
            
            let rightSide = (x + viewPort.origin.x) < layer.bounds.midX
            let startPoint = CGPoint(x: x, y: y)
            let endPoint = CGPoint(x: x + (rightSide ? 30 : -30 ), y: y)
            priceLinePath.move(to: startPoint)
            priceLinePath.addLine(to: endPoint)
            
            lowestTextLayer.string = formatter.format(item.low as NSNumber)
            let textSize = lowestTextLayer.preferredFrameSize()
            let textOrigin = CGPoint(
                x: endPoint.x + (rightSide ? 0 : -textSize.width),
                y: y - textSize.height * 0.5
            )
            lowestTextLayer.frame = CGRect(origin: textOrigin, size: textSize)
        }
        
        priceLineLayer.path = priceLinePath
        
        // MARK: - Latest price marker
        if let item = context.items.last {
            let dataBounds = context.layout.dataBounds
            let minY = layout.yPosition(for: dataBounds.max, viewPort: viewPort)
            let maxY = layout.yPosition(for: dataBounds.min, viewPort: viewPort)
            let rect = CGRectMake(0, viewPort.minY, layer.bounds.width, viewPort.height)
            let priceY = layout.yPosition(for: item.close, viewPort: viewPort)
            var y = priceY
            y = min(max(y, minY), maxY)
            let index = context.items.count - context.visibleRange.lowerBound - 1
            // Match the center x used by TimeSeriesRenderer, rather than the candle's left edge.
            let priceX = layout.xPosition(at: index) + (latestPointColor == nil ? 0 : candleDims.width * 0.5)
            let isLatestVisible = context.visibleRange.contains(context.items.count - 1)
                && priceX >= rect.minX && priceX <= rect.maxX
            let x = isLatestVisible ? priceX : 0
            let end = CGPoint(x: x, y: y)
            let start = CGPoint(x: rect.width, y: y)
            
            let path = CGMutablePath()
            path.move(to: start)
            path.addLine(to: end)
            dashLineLayer.path = path

            if latestPointColor != nil, isLatestVisible, priceY >= viewPort.minY, priceY <= viewPort.maxY {
                let radius: CGFloat = 3
                latestPointLayer.path = CGPath(ellipseIn: CGRect(
                    x: end.x - radius, y: end.y - radius, width: radius * 2, height: radius * 2
                ), transform: nil)
            }
            
            priceMarkView.showArrow = !isLatestVisible
            priceMarkView.label.text = formatter.format(item.close as NSNumber)
            let indicatorSize = priceMarkView.systemLayoutSizeFitting(rect.size)
            priceMarkView.bounds.size = indicatorSize
            priceMarkView.frame.origin.y = y - indicatorSize.height * 0.5
            priceMarkView.frame.origin.x = start.x - 12 - indicatorSize.width
        }
    }
}
