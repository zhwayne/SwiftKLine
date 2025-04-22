//
//  EMARenderer.swift
//  KLineDemo
//
//  Created by iya on 2024/11/6.
//

import UIKit

final class EMARenderer: Renderer {
    
    /// EMA线的配置结构体
    struct Configuration {
        /// EMA计算周期
        let period: Int
        /// 线的颜色
        let color: UIColor
    }
    
    typealias Calculator = EMACalculator
    
    /// 保存EMA线的配置信息
    private let configuration: Configuration
    /// 用于绘制EMA线的图层
    private let lineLayer = CAShapeLayer()
    
    /// MA指标计算器
    let calculator: Calculator?
    
    /// 初始化MA渲染器
    /// - Parameter configuration: MA线的配置信息
    init(configuration: Configuration) {
        self.configuration = configuration
        // 创建对应周期的MA计算器
        calculator = EMACalculator(period: configuration.period)
        // 设置线条宽度和填充色
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
        // 获取K线样式配置
        let candleStyle = context.candleStyle
        let layout = context.layout
        // 设置MA线颜色
        lineLayer.strokeColor = configuration.color.cgColor
        
        // 获取可见范围内的MA值
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
    
    func dataBounds(context: Context) -> MetricBounds {
        // 获取可见范围内的MA值
        guard let visibleValues = context.visibleValues?.compactMap({ $0 as? Double }),
              let min = visibleValues.min(),
              let max = visibleValues.max() else {
            return .empty
        }

        return MetricBounds(min: min, max: max)
    }
}

