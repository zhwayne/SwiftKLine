//
//  MARenderer.swift
//  KLineDemo
//
//  Created by iya on 2024/11/1.
//

import UIKit

/// 移动平均线(MA)渲染器
/// 负责计算和绘制K线图上的移动平均线
final class MARenderer: Renderer {

    private let priceFormatter = PriceFormatter()
    
    private let peroids: [Int]
    private let lineLayers: [CAShapeLayer]

    var id: some Hashable { Indicator.ma }

    init(peroids: [Int]) {
        self.peroids = peroids
        lineLayers = peroids.map { _ in
            let layer = CAShapeLayer()
            layer.lineWidth = 1
            layer.fillColor = UIColor.clear.cgColor
            return layer
        }
    }

    func install(to layer: CALayer) {
        lineLayers.forEach { layer.addSublayer($0) }
    }
    
    func uninstall(from layer: CALayer) {
        lineLayers.forEach { $0.removeFromSuperlayer() }
    }
    
    func draw(in layer: CALayer, context: Context) {
        // 获取K线样式配置
        let klineConfig = context.configuration
        let candleStyle = klineConfig.candleStyle
        let layout = context.layout
        let candleHalfWidth = candleStyle.width * 0.5
        let itemWidth = candleStyle.width + candleStyle.gap
        let visibleMinX = CGFloat(context.visibleRange.lowerBound) * itemWidth - layout.scrollView.contentOffset.x
        
        zip(peroids, lineLayers).forEach { period, lineLayer in
            let key = Indicator.Key.ma(period)
            guard let visibleValues = context.visibleValues(forKey: key, valueType: Double?.self) else {
                return
            }
            let style = klineConfig.indicatorStyle(for: key, type: LineStyle.self)
            lineLayer.strokeColor = style?.strokeColor.cgColor
            
            let path = CGMutablePath()
            var hasStartPoint = false
            for (idx, value) in visibleValues.enumerated() {
                guard let value else { continue }
                let x = CGFloat(idx) * itemWidth + visibleMinX + candleHalfWidth
                let y = layout.minY(for: value, viewPort: context.viewPort)
                let point = CGPoint(x: x, y: y)
                if hasStartPoint {
                    path.addLine(to: point)
                } else {
                    path.move(to: point)
                    hasStartPoint = true
                }
            }
            lineLayer.path = path
        }
    }
    
    func legend(context: Context) -> NSAttributedString? {
        return peroids.reduce(NSMutableAttributedString()) { partialResult, period in
            let key = Indicator.Key.ma(period)
            let style = context.configuration.indicatorStyle(for: key, type: LineStyle.self)
            guard let values = context.values(forKey: key, valueType: Double?.self), !values.isEmpty,
                  context.currentIndex >= 0,
                  context.currentIndex < values.count,
                  let value = values[context.currentIndex] else {
                return partialResult
            }
            let string = NSAttributedString(
                string: "MA\(period): \(priceFormatter.format(NSNumber(floatLiteral: value))) ",
                attributes: [
                    .foregroundColor: style?.strokeColor,
                    .font: context.configuration.legendFont
                ]
            )
            partialResult.append(string)
            return partialResult
        }
    }
    
    func dataBounds(context: Context) -> MetricBounds {
        var bounds = MetricBounds.empty
        for period in peroids {
            let key = Indicator.Key.ma(period)
            guard let visibleValues = context.visibleValues(forKey: key, valueType: Double?.self) else {
                continue
            }
            var minValue = Double.greatestFiniteMagnitude
            var maxValue = -Double.greatestFiniteMagnitude
            var hasValue = false
            for value in visibleValues {
                guard let value else { continue }
                hasValue = true
                minValue = Swift.min(minValue, value)
                maxValue = Swift.max(maxValue, value)
            }
            if hasValue {
                bounds.merge(other: MetricBounds(min: minValue, max: maxValue))
            }
        }
        return bounds
    }
}
