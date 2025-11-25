//
//  MACDRenderer.swift
//  SwiftKLine
//
//  Created by iya on 2025/4/1.
//

import UIKit

final class MACDRenderer: Renderer {
    
    var id: some Hashable { Indicator.macd }
    
    private let shortPeriod: Int = 12 // 短期 EMA 的周期（常用 12）
    private let longPeriod: Int  = 26 // 长期 EMA 的周期（常用 26）
    private let signalPeriod: Int = 9// 信号线 EMA 的周期（常用 9）
    private let priceFormatter = PriceFormatter()
    
    private let legendLayer = CATextLayer()
    private let macdLayer = CAShapeLayer()
    private let signalLayer = CAShapeLayer()
    private let barLayer = CALayer()
    
    init() {
        legendLayer.alignmentMode = .center
        legendLayer.contentsScale = UIScreen.main.scale
        
        macdLayer.lineWidth = 1
        macdLayer.fillColor = UIColor.clear.cgColor
        signalLayer.lineWidth = 1
        signalLayer.fillColor = UIColor.clear.cgColor
    }
    
    func install(to layer: CALayer) {
        layer.addSublayer(barLayer)
        layer.addSublayer(macdLayer)
        layer.addSublayer(signalLayer)
        layer.addSublayer(legendLayer)
    }
    
    func uninstall(from layer: CALayer) {
        barLayer.removeFromSuperlayer()
        macdLayer.removeFromSuperlayer()
        signalLayer.removeFromSuperlayer()
        legendLayer.removeFromSuperlayer()
    }
    
    func draw(in layer: CALayer, context: Context) {
        // 获取K线样式配置
        barLayer.sublayers = nil
        barLayer.frame = context.viewPort
        let klineConfig = context.configuration
        let candleStyle = klineConfig.candleStyle
        let layout = context.layout
        
        legendLayer.string = context.legendText
        legendLayer.frame = context.legendFrame
        
        let key = Indicator.Key.macd
        guard let visibleValues = context.visibleValues(forKey: key, valueType: MACDIndicatorValue?.self) else {
            return
        }
        let style = klineConfig.indicatorStyle(for: key, type: MACDStyle.self)

        for (idx, value) in visibleValues.enumerated() {
            guard let value else { continue }
            let shape = CAShapeLayer()
            shape.lineWidth = 1
            shape.contentsScale = UIScreen.main.scale
            
            let x = layout.minX(at: idx)
            let y1 = layout.minY(for: value.histogram > 0 ? value.histogram : 0, viewPort: barLayer.bounds)
            let y2 = layout.minY(for: value.histogram > 0 ? 0 : value.histogram, viewPort: barLayer.bounds)
            let height = max(y2 - y1, 0)
            let rect = CGRect(x: x, y: y1, width: candleStyle.width, height: height)
            let path = CGPath(rect: rect, transform: nil)
            shape.path = path
            
            var isFillMode = true
            var color = KLineTrend.rising.color(using: klineConfig).cgColor
            if idx > 0, let previousValue = visibleValues[visibleValues.startIndex.advanced(by: idx - 1)] {
                if value.histogram > 0 && value.histogram < previousValue.histogram {
                    isFillMode = false
                } else if value .histogram < 0 && value.histogram > previousValue.histogram {
                    isFillMode = false
                }
                if value.histogram < 0 {
                    color = KLineTrend.falling.color(using: klineConfig).cgColor
                }
            }
            
            shape.strokeColor = color
            if isFillMode {
                shape.fillColor = color
            } else {
                shape.fillColor = UIColor.clear.cgColor
            }
            
            barLayer.addSublayer(shape)
        }
        
        // 绘制折线
        let drawLine: (CAShapeLayer, UIColor?, [Double?]) -> Void = { lineLayer, color, values in
            lineLayer.strokeColor = color?.cgColor
            
            let path = UIBezierPath()
            var hasStartPoint = false
            for (idx, value) in values.enumerated() {
                guard let value else { continue }
                // 计算 x 坐标
                let x = layout.minX(at: idx) + candleStyle.width * 0.5
                let y = layout.minY(for: value, viewPort: context.viewPort)
                let point = CGPoint(x: x, y: y)
                
                if !hasStartPoint {
                    path.move(to: point)
                    hasStartPoint = true
                } else {
                    path.addLine(to: point)
                }
            }
            
            lineLayer.path = path.cgPath
        }
        
        drawLine(macdLayer, style?.macdColor, visibleValues.map(\.?.macd))
        drawLine(signalLayer, style?.deaColor, visibleValues.map(\.?.signal))
    }
    
    func legend(context: Context) -> NSAttributedString? {
        let key = Indicator.Key.macd
        let style = context.configuration.indicatorStyle(for: key, type: MACDStyle.self)
        guard let values = context.values(forKey: key, valueType: MACDIndicatorValue?.self), !values.isEmpty,
              context.currentIndex >= 0,
              context.currentIndex < values.count,
              let value = values[context.currentIndex] else {
            return nil
        }
        let partialResult = NSMutableAttributedString()
        partialResult.append(NSAttributedString(
            string: "STICK:\(priceFormatter.format(NSDecimalNumber(floatLiteral: value.histogram))) ",
            attributes: [
                .foregroundColor: style?.macdColor,
                .font: context.configuration.legendFont
            ]
        ))
        partialResult.append(NSAttributedString(
            string: "DIF:\(priceFormatter.format(NSDecimalNumber(floatLiteral: value.macd))) ",
            attributes: [
                .foregroundColor: style?.difColor,
                .font: context.configuration.legendFont
            ]
        ))
        partialResult.append(NSAttributedString(
            string: "DEA:\(priceFormatter.format(NSDecimalNumber(floatLiteral: value.signal))) ",
            attributes: [
                .foregroundColor: style?.deaColor,
                .font: context.configuration.legendFont
            ]
        ))
        return partialResult
    }
    
    func dataBounds(context: Context) -> MetricBounds {
        let key = Indicator.Key.macd
        let visibleValues = context.visibleValues(forKey: key, valueType: MACDIndicatorValue?.self)
        guard let visibleValues = visibleValues?.compactMap({ $0 }) else {
            return .empty
        }
        let mins = visibleValues.map(\.min)
        let maxies = visibleValues.map(\.max)
        guard let min = mins.min(), let max = maxies.max() else {
            return .empty
        }
        let maxValue = Swift.max(abs(min), abs(max))
        let bounds = MetricBounds(min: -maxValue, max: maxValue)
        return bounds
    }
}
