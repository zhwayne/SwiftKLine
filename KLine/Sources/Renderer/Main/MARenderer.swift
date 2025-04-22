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
    typealias Calculator = MACalculator
    
    private let period: Int
    private let style: LineStyle
    private let priceFormatter = PriceFormatter()
    /// 用于绘制MA线的图层
    private let lineLayer = CAShapeLayer()
    
    /// MA指标计算器
    let calculator: Calculator?
    
    init(period: Int, style: LineStyle) {
        self.period = period
        self.style = style
        calculator = MACalculator(period: period)
        lineLayer.lineWidth = 1
        lineLayer.fillColor = UIColor.clear.cgColor
    }
    
    /// 将MA线图层安装到指定图层上
    /// - Parameter layer: 父图层
    func install(to layer: CALayer) {
        layer.addSublayer(lineLayer)
    }
    
    /// 从指定图层中移除MA线图层
    /// - Parameter layer: 父图层
    func uninstall(from layer: CALayer) {
        lineLayer.removeFromSuperlayer()
    }
    
    /// 绘制MA线
    /// - Parameters:
    ///   - layer: 绘制所在的图层
    ///   - context: 绘制上下文，包含布局信息和数据
    func draw(in layer: CALayer, context: Context) {
        let candleStyle = context.candleStyle
        lineLayer.strokeColor = style.strokeColor.cgColor
        
        // 获取可见范围内的MA值
        guard let visibleValues = context.visibleValues as? [Double?] else {
            return
        }
        
        // 将MA值转换为坐标点
        let points = visibleValues.enumerated().compactMap { item -> CGPoint? in
            let (idx, value) = (item.offset, item.element)
            guard let value else { return nil }
            // 计算点的x坐标（基于索引位置）
            let x = context.layout.minX(at: idx) + candleStyle.width * 0.5
            // 计算点的y坐标（基于MA值）
            let y = context.layout.minY(for: value, viewPort: context.viewPort)
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
        let string = NSAttributedString(string: "MA\(period): \(priceFormatter.format(value as NSNumber)) ", attributes: [
            .foregroundColor: style.strokeColor.cgColor
        ])
        return (.ma, string)
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
