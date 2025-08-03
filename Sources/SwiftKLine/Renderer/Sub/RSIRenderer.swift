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
    private let range: ClosedRange<Double>
    private let rangeColor = UIColor.systemBlue.withAlphaComponent(0.8)
    private let lineLayers: [CAShapeLayer]
    private let areaLayer = CAShapeLayer()
    private let dashLayer = CAShapeLayer()
    private let legendLayer = CATextLayer()

    var id: some Hashable { Indicator.rsi }

    init(peroids: [Int]) {
        self.peroids = peroids
        range = 30...70
        lineLayers = peroids.map { _ in
            let layer = CAShapeLayer()
            layer.lineWidth = 1
            layer.fillColor = UIColor.clear.cgColor
            return layer
        }
        legendLayer.alignmentMode = .center
        legendLayer.contentsScale = UIScreen.main.scale
        areaLayer.strokeColor = UIColor.clear.cgColor
        dashLayer.lineWidth = 1
        dashLayer.lineDashPattern = [2, 2]
        dashLayer.fillColor = UIColor.clear.cgColor
    }

    func install(to layer: CALayer) {
        layer.addSublayer(areaLayer)
        layer.addSublayer(dashLayer)
        lineLayers.forEach { layer.addSublayer($0) }
        layer.addSublayer(legendLayer)
    }
    
    func uninstall(from layer: CALayer) {
        areaLayer.removeFromSuperlayer()
        dashLayer.removeFromSuperlayer()
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
        
        // 绘制超买超卖区域
            let oby = layout.minY(for: range.upperBound, viewPort: context.viewPort)
            let osy = layout.minY(for: range.lowerBound, viewPort: context.viewPort)
        let minX = layout.minX(at: 0) + candleStyle.width * 0.5
        let maxX = layout.minX(at: context.visibleRange.count - 1) + candleStyle.width * 0.5
        let overRect = CGRect(x: minX, y: oby, width: maxX - minX, height: osy - oby)
        areaLayer.path = CGPath(rect: overRect, transform: nil)
        areaLayer.fillColor = rangeColor.withAlphaComponent(0.1).cgColor
        
        let dashPath = CGMutablePath()
        dashPath.move(to: CGPoint(x: overRect.minX, y: overRect.minY))
        dashPath.addLine(to: CGPoint(x: overRect.maxX, y: overRect.minY))
        dashPath.move(to: CGPoint(x: overRect.minX, y: overRect.maxY))
        dashPath.addLine(to: CGPoint(x: overRect.maxX, y: overRect.maxY))
        dashLayer.path = dashPath
        dashLayer.strokeColor = rangeColor.cgColor
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
            let rangeBounds = MetricBounds(range: range)
            return bounds
                .merging(other: partialResult)
                .merging(other: rangeBounds)
        }
    }
}
