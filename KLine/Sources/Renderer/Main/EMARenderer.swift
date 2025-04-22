//
//  EMARenderer.swift
//  KLineDemo
//
//  Created by iya on 2024/11/6.
//

import UIKit

final class EMARenderer: Renderer {
    typealias Calculator = EMACalculator
    
    private let priceFormatter = PriceFormatter()
    
    private let period: Int
    private let style: LineStyle
    private let lineLayer = CAShapeLayer()
    
    let calculator: Calculator?

    init(period: Int, style: LineStyle) {
        self.period = period
        self.style = style
        calculator = EMACalculator(period: period)
        lineLayer.lineWidth = 1
        lineLayer.fillColor = UIColor.clear.cgColor
    }

    func install(to layer: CALayer) {
        layer.addSublayer(lineLayer)
    }
    
    func uninstall(from layer: CALayer) {
        lineLayer.removeFromSuperlayer()
    }
    
    func draw(in layer: CALayer, context: Context) {
        // 获取K线样式配置
        let candleStyle = context.candleStyle
        let layout = context.layout
        lineLayer.strokeColor = style.strokeColor.cgColor
        
        guard let visibleValues = context.visibleValues as? [Double?] else {
            return
        }
        
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
    
    func legend(at index: Int, context: Context) -> (Indicator, NSAttributedString)? {
        guard let visibleValues = context.visibleValues as? [Double?],
              let value = visibleValues[index] else {
            return nil
        }
        let string = NSAttributedString(string: "EMA\(period): \(priceFormatter.format(value as NSNumber)) ", attributes: [
            .foregroundColor: style.strokeColor.cgColor
        ])
        return (.ema, string)
    }
    
    func dataBounds(context: Context) -> MetricBounds {
        guard let visibleValues = context.visibleValues?.compactMap({ $0 as? Double }),
              let min = visibleValues.min(),
              let max = visibleValues.max() else {
            return .empty
        }

        return MetricBounds(min: min, max: max)
    }
}

