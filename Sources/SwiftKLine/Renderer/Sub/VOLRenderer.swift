//
//  VOLRenderer.swift
//  KLineDemo
//
//  Created by iya on 2025/3/24.
//

import UIKit

final class VOLRenderer: Renderer {
    
    private let risingLayer = CAShapeLayer()
    private let fallingLayer = CAShapeLayer()
    private let legendLayer = CATextLayer()
    private let volumeFormatter = VolumeFormatter()
    
    var id: some Hashable { Indicator.vol }
        
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
        
        legendLayer.string = context.legendText
        legendLayer.frame = context.legendFrame
        
        let upPath = CGMutablePath()
        let downPath = CGMutablePath()
        for (idx, item) in visibleItems.enumerated() {
            // 计算 x 坐标
            let x = layout.minX(at: idx)
            let y = layout.minY(for: item.volume, viewPort: viewPort)
            let height = viewPort.maxY - y
            let rect = CGRect(x: x, y: y, width: candleStyle.width, height: height)
            let trend = item.trend
            let candlePath = trend == .falling ? downPath : upPath
            candlePath.addRect(rect)
        }
        risingLayer.path = upPath
        fallingLayer.path = downPath
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
                .font: context.configuration.legendFont
            ]
        )
        return string
    }
    
    func dataBounds(context: Context) -> MetricBounds {
        let visibleItems = context.visibleItems
        guard let max = visibleItems.max(by: { $0.volume < $1.volume }) else {
            return .empty
        }
        return MetricBounds(min: 0, max: max.volume)
    }
}
