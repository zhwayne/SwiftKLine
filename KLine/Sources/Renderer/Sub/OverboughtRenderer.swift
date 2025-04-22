//
//  OverboughtRenderer.swift
//  KLine
//
//  Created by iya on 2025/4/26.
//

import UIKit

final class OverboughtRenderer: Renderer {
    
    typealias Calculator = NothingCalculator
    
    private let range: ClosedRange<Double>
    
    private let areaLayer = CAShapeLayer()
    private let dashLayer = CAShapeLayer()
    private let color = UIColor.systemBlue.withAlphaComponent(0.8)
    
    init(range: ClosedRange<Double>) {
        self.range = range
        areaLayer.strokeColor = UIColor.clear.cgColor
        dashLayer.lineWidth = 1
        dashLayer.lineDashPattern = [2, 2]
        dashLayer.fillColor = UIColor.clear.cgColor
    }
    
    func install(to layer: CALayer) {
        layer.addSublayer(areaLayer)
        layer.addSublayer(dashLayer)
    }
    
    func uninstall(from layer: CALayer) {
        areaLayer.removeFromSuperlayer()
        dashLayer.removeFromSuperlayer()
    }
    
    func draw(in layer: CALayer, context: Context) {
        let candleStyle = context.candleStyle
        let layout = context.layout
        let viewPort = context.viewPort
        
        guard let visibleValues = context.visibleValues as? [Double?] else {
            return
        }
    
        let oby = layout.minY(for: range.upperBound, viewPort: viewPort)
        let osy = layout.minY(for: range.lowerBound, viewPort: viewPort)
        let minX = layout.minX(at: 0) + candleStyle.width * 0.5
        let maxX = layout.minX(at: visibleValues.count - 1) + candleStyle.width * 0.5
        let overRect = CGRect(x: minX, y: oby, width: maxX - minX, height: osy - oby)
        areaLayer.path = CGPath(rect: overRect, transform: nil)
        areaLayer.fillColor = color.withAlphaComponent(0.1).cgColor
        
        let dashPath = CGMutablePath()
        dashPath.move(to: CGPoint(x: overRect.minX, y: overRect.minY))
        dashPath.addLine(to: CGPoint(x: overRect.maxX, y: overRect.minY))
        dashPath.move(to: CGPoint(x: overRect.minX, y: overRect.maxY))
        dashPath.addLine(to: CGPoint(x: overRect.maxX, y: overRect.maxY))
        dashLayer.path = dashPath
        dashLayer.strokeColor = color.cgColor
    }
    
    func dataBounds(context: Context) -> MetricBounds {
        return MetricBounds(range: range)
    }
}
