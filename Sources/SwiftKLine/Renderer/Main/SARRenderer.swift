//
//  SARRenderer.swift
//  SwiftKLine
//
//  Created by W Zh on 2025/8/7.
//

import UIKit

final class SARRenderer: Renderer {
    
    private let priceFormatter = PriceFormatter()
    
    private let rectLayer = CAShapeLayer()

    var id: some Hashable { Indicator.sar }

    init() {
        rectLayer.lineWidth = 1
        rectLayer.fillColor = UIColor.clear.cgColor
    }

    func install(to layer: CALayer) {
        layer.addSublayer(rectLayer)
    }
    
    func uninstall(from layer: CALayer) {
        rectLayer.removeFromSuperlayer()
    }
    
    func draw(in layer: CALayer, context: Context) {
        // 获取K线样式配置
        let klineConfig = KLineConfig.default
        let candleStyle = klineConfig.candleStyle
        let layout = context.layout

        let key = Indicator.Key.sar
        guard let visibleValues = context.visibleValues(forKey: key, valueType: Double?.self) else {
            return
        }
        let style = KLineConfig.default.indicatorStyle(for: key, type: LineStyle.self)
        rectLayer.strokeColor = style?.strokeColor.cgColor
        
        let path = CGMutablePath()
        for (idx, value) in visibleValues.enumerated() {
            guard let value else { continue }
            let x = layout.minX(at: idx) + candleStyle.width * 0.5
            let y = layout.minY(for: value, viewPort: context.viewPort)
            let rect = CGRect(x: x - 2, y: y - 2, width: 4, height: 4)
            path.addRect(rect)
        }
        rectLayer.path = path
    }
    
    func legend(context: Context) -> NSAttributedString? {
        let key = Indicator.Key.sar
        let style = KLineConfig.default.indicatorStyle(for: key, type: LineStyle.self)
        guard let values = context.values(forKey: key, valueType: Double?.self), !values.isEmpty,
              context.currentIndex >= 0,
              context.currentIndex < values.count,
              let value = values[context.currentIndex] else {
            return nil
        }
        let partialResult = NSMutableAttributedString()
        partialResult.append(NSAttributedString(
            string: "\(key.description):\(priceFormatter.format(NSDecimalNumber(floatLiteral: value))) ",
            attributes: [
                .foregroundColor: style?.strokeColor,
                .font: KLineConfig.default.legendFont
            ]
        ))
        return partialResult
    }
    
    func dataBounds(context: Context) -> MetricBounds {
        let key = Indicator.Key.sar
        let visibleValues = context.visibleValues(forKey: key, valueType: Double?.self)
        guard let visibleValues = visibleValues?.compactMap({ $0 }),
              let min = visibleValues.min(),
              let max = visibleValues.max() else {
            return .empty
        }
        return MetricBounds(min: min, max: max)
    }
}
