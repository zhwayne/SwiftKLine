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
   
    struct Configuration {
        let period: Int
        let style: LineStyle
        var key: Indicator.Key { .ma(period) }
    }
    
    private let priceFormatter = PriceFormatter()
    
    private let configurations: [Configuration]
    private let lineLayers: [CAShapeLayer]

    var id: some Hashable { Indicator.ma }

    init(configurations: [Configuration]) {
        self.configurations = configurations
        lineLayers = configurations.map { _ in
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
        let candleStyle = context.candleStyle
        let layout = context.layout
        
        zip(configurations, lineLayers).forEach { config, lineLayer in
            guard let visibleValues = context.visibleValues(forKey: config.key, valueType: Double?.self) else {
                return
            }
            lineLayer.strokeColor = config.style.strokeColor.cgColor
            
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
        return configurations.reduce(NSMutableAttributedString()) { partialResult, config in
            guard let values = context.values(forKey: config.key, valueType: Double?.self),
                  let value = values[context.currentIndex] else {
                return partialResult
            }
            let string = NSAttributedString(
                string: "MA\(config.period): \(priceFormatter.format(NSNumber(floatLiteral: value))) ",
                attributes: [
                    .foregroundColor: config.style.strokeColor.cgColor,
                    .font: UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
                ]
            )
            partialResult.append(string)
            return partialResult
        }
    }
    
    func dataBounds(context: Context) -> MetricBounds {
        return configurations.reduce(MetricBounds.empty) { partialResult, config in
            let visibleValues = context.visibleValues(forKey: config.key, valueType: Double?.self)
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
