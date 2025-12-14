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
    private let positiveFilledBarsLayer = CAShapeLayer()
    private let positiveHollowBarsLayer = CAShapeLayer()
    private let negativeFilledBarsLayer = CAShapeLayer()
    private let negativeHollowBarsLayer = CAShapeLayer()
    
    init() {
        legendLayer.alignmentMode = .center
        legendLayer.contentsScale = UIScreen.main.scale
        
        macdLayer.lineWidth = 1
        macdLayer.fillColor = UIColor.clear.cgColor
        signalLayer.lineWidth = 1
        signalLayer.fillColor = UIColor.clear.cgColor
        
        [positiveFilledBarsLayer, positiveHollowBarsLayer, negativeFilledBarsLayer, negativeHollowBarsLayer].forEach { layer in
            layer.lineWidth = 1
            layer.contentsScale = UIScreen.main.scale
        }
        positiveHollowBarsLayer.fillColor = UIColor.clear.cgColor
        negativeHollowBarsLayer.fillColor = UIColor.clear.cgColor
    }
    
    func install(to layer: CALayer) {
        layer.addSublayer(barLayer)
        barLayer.addSublayer(positiveFilledBarsLayer)
        barLayer.addSublayer(positiveHollowBarsLayer)
        barLayer.addSublayer(negativeFilledBarsLayer)
        barLayer.addSublayer(negativeHollowBarsLayer)
        layer.addSublayer(macdLayer)
        layer.addSublayer(signalLayer)
        layer.addSublayer(legendLayer)
    }
    
    func uninstall(from layer: CALayer) {
        positiveFilledBarsLayer.removeFromSuperlayer()
        positiveHollowBarsLayer.removeFromSuperlayer()
        negativeFilledBarsLayer.removeFromSuperlayer()
        negativeHollowBarsLayer.removeFromSuperlayer()
        barLayer.removeFromSuperlayer()
        macdLayer.removeFromSuperlayer()
        signalLayer.removeFromSuperlayer()
        legendLayer.removeFromSuperlayer()
    }
    
    func draw(in layer: CALayer, context: Context) {
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

        let risingColor = KLineTrend.rising.color(using: klineConfig).cgColor
        let fallingColor = KLineTrend.falling.color(using: klineConfig).cgColor
        
        positiveFilledBarsLayer.frame = barLayer.bounds
        positiveHollowBarsLayer.frame = barLayer.bounds
        negativeFilledBarsLayer.frame = barLayer.bounds
        negativeHollowBarsLayer.frame = barLayer.bounds
        
        positiveFilledBarsLayer.strokeColor = risingColor
        positiveFilledBarsLayer.fillColor = risingColor
        positiveHollowBarsLayer.strokeColor = risingColor
        
        negativeFilledBarsLayer.strokeColor = fallingColor
        negativeFilledBarsLayer.fillColor = fallingColor
        negativeHollowBarsLayer.strokeColor = fallingColor
        
        let positiveFilledPath = CGMutablePath()
        let positiveHollowPath = CGMutablePath()
        let negativeFilledPath = CGMutablePath()
        let negativeHollowPath = CGMutablePath()
        
        var previousHistogram: Double?
        for (idx, value) in visibleValues.enumerated() {
            guard let value else {
                previousHistogram = nil
                continue
            }
            
            let histogram = value.histogram
            let x = layout.minX(at: idx) - context.viewPort.minX
            let yTop = layout.minY(for: max(histogram, 0), viewPort: barLayer.bounds)
            let yBottom = layout.minY(for: min(histogram, 0), viewPort: barLayer.bounds)
            let height = max(yBottom - yTop, 0)
            let rect = CGRect(x: x, y: yTop, width: candleStyle.width, height: height)
            
            let isHollow: Bool
            if let previousHistogram {
                if histogram > 0 {
                    isHollow = histogram < previousHistogram
                } else if histogram < 0 {
                    isHollow = histogram > previousHistogram
                } else {
                    isHollow = false
                }
            } else {
                isHollow = false
            }
            
            let targetPath: CGMutablePath
            if histogram >= 0 {
                targetPath = isHollow ? positiveHollowPath : positiveFilledPath
            } else {
                targetPath = isHollow ? negativeHollowPath : negativeFilledPath
            }
            targetPath.addRect(rect)
            previousHistogram = histogram
        }
        
        positiveFilledBarsLayer.path = positiveFilledPath
        positiveHollowBarsLayer.path = positiveHollowPath
        negativeFilledBarsLayer.path = negativeFilledPath
        negativeHollowBarsLayer.path = negativeHollowPath
        
        // 绘制折线
        let drawLine: (CAShapeLayer, UIColor?, (MACDIndicatorValue) -> Double) -> Void = { lineLayer, color, extractor in
            lineLayer.strokeColor = color?.cgColor
            
            let path = UIBezierPath()
            var hasStartPoint = false
            for (idx, value) in visibleValues.enumerated() {
                guard let value else { continue }
                let yValue = extractor(value)
                // 计算 x 坐标
                let x = layout.minX(at: idx) + candleStyle.width * 0.5
                let y = layout.minY(for: yValue, viewPort: context.viewPort)
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
        
        drawLine(macdLayer, style?.macdColor, { $0.macd })
        drawLine(signalLayer, style?.deaColor, { $0.signal })
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
