//
//  RSIRenderer.swift
//  KLineDemo
//
//  Created by iya on 2024/11/6.
//

import UIKit

final class RSIRenderer: Renderer {

    private let priceFormatter = PriceFormatter()
    
    private let peroids: [Int]
    private let lineLayers: [CAShapeLayer]
    private let legendLayer = CATextLayer()

    var id: some Hashable { Indicator.rsi }

    init(peroids: [Int]) {
        self.peroids = peroids
        lineLayers = peroids.map { _ in
            let layer = CAShapeLayer()
            layer.lineWidth = 1
            layer.fillColor = UIColor.clear.cgColor
            return layer
        }
        legendLayer.alignmentMode = .center
        legendLayer.contentsScale = UIScreen.main.scale
    }

    func install(to layer: CALayer) {
        layer.addSublayer(legendLayer)
        lineLayers.forEach { layer.addSublayer($0) }
    }
    
    func uninstall(from layer: CALayer) {
        legendLayer.removeFromSuperlayer()
        lineLayers.forEach { $0.removeFromSuperlayer() }
    }
    
    func draw(in layer: CALayer, context: Context) {
        // 获取K线样式配置
        let klineConfig = KLineConfig.default
        let candleStyle = klineConfig.candleStyle
        let layout = context.layout
        
        legendLayer.string = context.legendText
        legendLayer.frame = context.legendFrame
        
        zip(peroids, lineLayers).forEach { period, lineLayer in
            let key = Indicator.Key.rsi(period)
            guard let visibleValues = context.visibleValues(forKey: key, valueType: Double?.self) else {
                return
            }
            let style = klineConfig.indicatorStyle(for: key, type: LineStyle.self)
            lineLayer.strokeColor = style?.strokeColor.cgColor
            
            // 将MA值转换为坐标点
            let points = visibleValues.enumerated().compactMap { item -> CGPoint? in
                let (idx, value) = (item.offset, item.element)
                guard let value else { return nil }
                // 计算点的x坐标（基于索引位置）
                let x = layout.minX(at: idx) + candleStyle.width * 0.5
                // 计算点的y坐标（基于MA值）
                let y = layout.minY(for: value, viewPort: context.viewPort)
                return CGPoint(x: x, y: y)
            }
            
            // 使用计算出的点创建路径并设置到图层
            lineLayer.path = points.cgPath
        }
    }
    
    func legend(context: Context) -> NSAttributedString? {
        return peroids.reduce(NSMutableAttributedString()) { partialResult, period in
            let key = Indicator.Key.rsi(period)
            let style = KLineConfig.default.indicatorStyle(for: key, type: LineStyle.self)
            guard let values = context.values(forKey: key, valueType: Double?.self),
                  let value = values[context.currentIndex] else {
                return partialResult
            }
            let string = NSAttributedString(
                string: "RSI\(period): \(priceFormatter.format(NSNumber(floatLiteral: value))) ",
                attributes: [
                    .foregroundColor: style?.strokeColor.cgColor,
                    .font: KLineConfig.default.legendFont
                ]
            )
            partialResult.append(string)
            return partialResult
        }
    }
    
    func dataBounds(context: Context) -> MetricBounds {
        return peroids.reduce(MetricBounds.empty) { partialResult, period in
            let key = Indicator.Key.rsi(period)
            let visibleValues = context.visibleValues(forKey: key, valueType: Double?.self)
            guard let visibleValues = visibleValues?.compactMap({ $0 }),
                  let min = visibleValues.min(),
                  let max = visibleValues.max() else {
                return partialResult
            }
            let bounds = MetricBounds(min: min, max: max)
            return bounds.merging(other: partialResult)
        }
    }
}
