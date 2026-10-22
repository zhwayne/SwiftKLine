//
//  VOLRenderer.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2025/03/24.
//

import SwiftKLineCore
import UIKit

/// Draws visible traded quantities with candle-direction colors and a selected-volume legend.
final class VOLRenderer: ChartRenderer, LegendUpdatable {
    
    private let risingLayer = CAShapeLayer()
    private let fallingLayer = CAShapeLayer()
    private let legendLayer = CATextLayer()
    private let volumeFormatter = VolumeFormatter()
    
    var id: some Hashable { BuiltInIndicator.vol }
        
    init() {
        risingLayer.lineWidth = 1
        risingLayer.opacity = 0.5
        
        fallingLayer.lineWidth = 1
        fallingLayer.opacity = 0.5
        
        legendLayer.alignmentMode = .center
        legendLayer.contentsScale = UIScreen.main.scale
    }
    
    func install(to layer: CALayer) {
        layer.addSublayer(legendLayer)
        layer.addSublayer(risingLayer)
        layer.addSublayer(fallingLayer)
    }
    
    func uninstall(from layer: CALayer) {
        legendLayer.removeFromSuperlayer()
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
        
        updateLegend(context: context)
        
        let upPath = CGMutablePath()
        let downPath = CGMutablePath()
        let itemWidth = candleDims.itemWidth
        let visibleMinX = CGFloat(context.visibleRange.lowerBound) * itemWidth - layout.scrollView.contentOffset.x
        for (idx, item) in visibleItems.enumerated() {
            // Position the candle or bar on the shared horizontal scale.
            let x = CGFloat(idx) * itemWidth + visibleMinX
            let y = layout.yPosition(for: item.volume, viewPort: viewPort)
            let height = viewPort.maxY - y
            let rect = CGRect(x: x, y: y, width: candleDims.width, height: height)
            let trend = item.trend
            let candlePath = trend == .falling ? downPath : upPath
            candlePath.addRect(rect)
        }
        risingLayer.path = upPath
        fallingLayer.path = downPath
    }

    func updateLegend(context: Context) {
        legendLayer.string = context.legendText
        legendLayer.frame = context.legendFrame
    }
    
    func legend(context: Context) -> NSAttributedString? {
        let items = context.items
        guard !items.isEmpty,
              context.currentIndex >= 0,
              context.currentIndex < items.count else {
            return nil
        }
        let item = items[context.currentIndex]
        let string = NSAttributedString(
            string: "VOL: \(volumeFormatter.format(NSNumber(floatLiteral: item.volume))) ",
            attributes: [
                .foregroundColor: UIColor.secondaryLabel,
                .font: context.appearance.legendFont
            ]
        )
        return string
    }
    
    func dataBounds(context: Context) -> ValueBounds {
        let visibleItems = context.visibleItems
        guard let max = visibleItems.max(by: { $0.volume < $1.volume }) else {
            return .empty
        }
        return ValueBounds(min: 0, max: max.volume)
    }
}
