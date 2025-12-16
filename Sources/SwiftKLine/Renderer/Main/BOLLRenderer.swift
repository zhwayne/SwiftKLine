//
//  BOLLRenderer.swift
//  SwiftKLine
//
//  Created by W Zh on 2025/8/6.
//

import UIKit

final class BOLLRenderer: Renderer {
    
    private let priceFormatter = PriceFormatter()
    
    private let upperLayer = CAShapeLayer()
    private let middleLayer = CAShapeLayer()
    private let lowerLayer = CAShapeLayer()
    private let areaLayer = CAShapeLayer()

    var id: some Hashable { Indicator.boll }

    init() {
        upperLayer.lineWidth = 1
        upperLayer.fillColor = UIColor.clear.cgColor
        middleLayer.lineWidth = 1
        middleLayer.fillColor = UIColor.clear.cgColor
        lowerLayer.lineWidth = 1
        lowerLayer.fillColor = UIColor.clear.cgColor
        areaLayer.strokeColor = UIColor.clear.cgColor
    }

    func install(to layer: CALayer) {
        layer.addSublayer(areaLayer)
        layer.addSublayer(upperLayer)
        layer.addSublayer(middleLayer)
        layer.addSublayer(lowerLayer)
    }
    
    func uninstall(from layer: CALayer) {
        areaLayer.removeFromSuperlayer()
        upperLayer.removeFromSuperlayer()
        middleLayer.removeFromSuperlayer()
        lowerLayer.removeFromSuperlayer()
    }
    
    func draw(in layer: CALayer, context: Context) {
        // 获取K线样式配置
        let klineConfig = context.configuration
        let candleStyle = klineConfig.candleStyle
        let layout = context.layout
        
        let key = Indicator.Key.boll
        guard let visibleValues = context.visibleValues(forKey: key, valueType: BOLLIndicatorValue?.self) else {
            return
        }
        let style = context.configuration.indicatorStyle(for: key, type: LineStyle.self)
        upperLayer.strokeColor = style?.strokeColor.cgColor
        middleLayer.strokeColor = style?.strokeColor.cgColor
        lowerLayer.strokeColor = style?.strokeColor.cgColor
        areaLayer.fillColor =  style?.strokeColor.withAlphaComponent(0.05).cgColor
        
        let itemWidth = candleStyle.width + candleStyle.gap
        let candleHalfWidth = candleStyle.width * 0.5
        let visibleMinX = CGFloat(context.visibleRange.lowerBound) * itemWidth - layout.scrollView.contentOffset.x

        // 绘制上柜和下轨
        let upperPath = CGMutablePath()
        let middlePath = CGMutablePath()
        let lowerPath = CGMutablePath()
        let areaPath = CGMutablePath()
        for (idx, value) in visibleValues.enumerated() {
            guard let value else { continue }
            let x = CGFloat(idx) * itemWidth + visibleMinX + candleHalfWidth
            let upperY = layout.minY(for: value.upper, viewPort: context.viewPort)
            let middleY = layout.minY(for: value.middle, viewPort: context.viewPort)
            let lowerY = layout.minY(for: value.lower, viewPort: context.viewPort)
            if idx > 0 {
                areaPath.addLine(to: CGPoint(x: x, y: upperY))
                upperPath.addLine(to: CGPoint(x: x, y: upperY))
                middlePath.addLine(to: CGPoint(x: x, y: middleY))
                lowerPath.addLine(to: CGPoint(x: x, y: lowerY))
            } else {
                areaPath.move(to: CGPoint(x: x, y: upperY))
                upperPath.move(to: CGPoint(x: x, y: upperY))
                middlePath.move(to: CGPoint(x: x, y: middleY))
                lowerPath.move(to: CGPoint(x: x, y: lowerY))
            }
        }
        for (idx, value) in visibleValues.enumerated().reversed() {
            guard let value else { continue }
            let lowerY = layout.minY(for: value.lower, viewPort: context.viewPort)
            let x = CGFloat(idx) * itemWidth + visibleMinX + candleHalfWidth
            areaPath.addLine(to: CGPoint(x: x, y: lowerY))
        }
        areaPath.closeSubpath()
        upperLayer.path = upperPath
        middleLayer.path = middlePath
        lowerLayer.path = lowerPath
        areaLayer.path = areaPath
    }
    
    func legend(context: Context) -> NSAttributedString? {
        let key = Indicator.Key.boll
        let style = context.configuration.indicatorStyle(for: key, type: LineStyle.self)
        guard let values = context.values(forKey: key, valueType: BOLLIndicatorValue?.self), !values.isEmpty,
              context.currentIndex >= 0,
              context.currentIndex < values.count,
              let value = values[context.currentIndex] else {
            return nil
        }
        let partialResult = NSMutableAttributedString()
        partialResult.append(NSAttributedString(
            string: "BOLL:\(priceFormatter.format(NSDecimalNumber(floatLiteral: value.middle))) ",
            attributes: [
                .foregroundColor: style?.strokeColor,
                .font: context.configuration.legendFont
            ]
        ))
        partialResult.append(NSAttributedString(
            string: "UB:\(priceFormatter.format(NSDecimalNumber(floatLiteral: value.upper))) ",
            attributes: [
                .foregroundColor: style?.strokeColor,
                .font: context.configuration.legendFont
            ]
        ))
        partialResult.append(NSAttributedString(
            string: "LB:\(priceFormatter.format(NSDecimalNumber(floatLiteral: value.lower))) ",
            attributes: [
                .foregroundColor: style?.strokeColor,
                .font: context.configuration.legendFont
            ]
        ))
        return partialResult
    }
    
    func dataBounds(context: Context) -> MetricBounds {
        let key = Indicator.Key.boll
        let visibleValues = context.visibleValues(forKey: key, valueType: BOLLIndicatorValue?.self)
        guard let visibleValues else {
            return .empty
        }
        var minValue = Double.greatestFiniteMagnitude
        var maxValue = -Double.greatestFiniteMagnitude
        var hasValue = false
        for value in visibleValues {
            guard let value else { continue }
            hasValue = true
            minValue = Swift.min(minValue, value.min)
            maxValue = Swift.max(maxValue, value.max)
        }
        guard hasValue else {
            return .empty
        }
        return MetricBounds(min: minValue, max: maxValue)
    }
}
