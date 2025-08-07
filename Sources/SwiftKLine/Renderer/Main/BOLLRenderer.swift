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
        let klineConfig = KLineConfig.default
        let candleStyle = klineConfig.candleStyle
        let layout = context.layout
        
        let key = Indicator.Key.boll
        guard let visibleValues = context.visibleValues(forKey: key, valueType: BOLLIndicatorValue?.self) else {
            return
        }
        let style = KLineConfig.default.indicatorStyle(for: key, type: LineStyle.self)
        upperLayer.strokeColor = style?.strokeColor.cgColor
        middleLayer.strokeColor = style?.strokeColor.cgColor
        lowerLayer.strokeColor = style?.strokeColor.cgColor
        areaLayer.fillColor =  style?.strokeColor.withAlphaComponent(0.05).cgColor
        
        // 绘制上柜和下轨
        let upperPath = CGMutablePath()
        let middlePath = CGMutablePath()
        let lowerPath = CGMutablePath()
        let areaPath = CGMutablePath()
        for (idx, value) in visibleValues.enumerated() {
            guard let value else { continue }
            let x = layout.minX(at: idx) + candleStyle.width * 0.5
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
            let x = layout.minX(at: idx) + candleStyle.width * 0.5
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
        let style = KLineConfig.default.indicatorStyle(for: key, type: LineStyle.self)
        guard let values = context.values(forKey: key, valueType: BOLLIndicatorValue?.self),
              let value = values[context.currentIndex] else {
            return nil
        }
        let partialResult = NSMutableAttributedString()
        partialResult.append(NSAttributedString(
            string: "BOLL:\(priceFormatter.format(NSDecimalNumber(floatLiteral: value.middle))) ",
            attributes: [
                .foregroundColor: style?.strokeColor,
                .font: KLineConfig.default.legendFont
            ]
        ))
        partialResult.append(NSAttributedString(
            string: "UB:\(priceFormatter.format(NSDecimalNumber(floatLiteral: value.upper))) ",
            attributes: [
                .foregroundColor: style?.strokeColor,
                .font: KLineConfig.default.legendFont
            ]
        ))
        partialResult.append(NSAttributedString(
            string: "LB:\(priceFormatter.format(NSDecimalNumber(floatLiteral: value.lower))) ",
            attributes: [
                .foregroundColor: style?.strokeColor,
                .font: KLineConfig.default.legendFont
            ]
        ))
        return partialResult
    }
    
    func dataBounds(context: Context) -> MetricBounds {
        let key = Indicator.Key.boll
        let visibleValues = context.visibleValues(forKey: key, valueType: BOLLIndicatorValue?.self)
        guard let visibleValues = visibleValues?.compactMap({ $0 }) else {
            return .empty
        }
        let mins = visibleValues.map(\.min)
        let maxies = visibleValues.map(\.max)
        guard let min = mins.min(), let max = maxies.max() else {
            return .empty
        }
        return MetricBounds(min: min, max: max)
    }
}
