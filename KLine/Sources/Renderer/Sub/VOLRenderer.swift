//
//  VOLRenderer.swift
//  KLineDemo
//
//  Created by iya on 2025/3/24.
//

import UIKit

final class VOLRenderer: Renderer {
    
    struct Configuration {
        var key: Indicator.Key { .vol }
    }
    
    private let risingLayer = CAShapeLayer()
    private let fallingLayer = CAShapeLayer()
    private let legendLayer = CATextLayer()
    private let volumeFormatter = VolumeFormatter()
    private let configuration: Configuration
    
    var id: some Hashable { Indicator.vol }
        
    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        risingLayer.lineWidth = 1
        risingLayer.contentsScale = UIScreen.main.scale
        risingLayer.opacity = 0.5
        
        fallingLayer.lineWidth = 1
        fallingLayer.contentsScale = UIScreen.main.scale
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
        let candleStyle = context.candleStyle
        let layout = context.layout
        let viewPort = context.viewPort
        let visibleItems = context.visibleItems
        risingLayer.fillColor = KLineTrend.rising.color
        risingLayer.strokeColor = KLineTrend.rising.color
        fallingLayer.fillColor = KLineTrend.falling.color
        fallingLayer.strokeColor = KLineTrend.falling.color
        
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
            
            let path = CGMutablePath(rect: rect, transform: nil)
            let trend = item.trend
            let candlePath = trend == .falling ? downPath : upPath
            candlePath.addPath(path)
        }
        risingLayer.path = upPath
        fallingLayer.path = downPath
    }
    
    func legend(context: Context) -> NSAttributedString? {
        let item = context.items[context.currentIndex]
        let string = NSAttributedString(
            string: "VOL: \(volumeFormatter.format(NSNumber(floatLiteral: item.volume))) ",
            attributes: [
                .foregroundColor: UIColor.secondaryLabel.cgColor,
                .font: UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
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
