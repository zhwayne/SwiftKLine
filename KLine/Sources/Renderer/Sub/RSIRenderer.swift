//
//  RSIRenderer.swift
//  KLineDemo
//
//  Created by iya on 2024/11/6.
//

import UIKit

final class RSIRenderer: Renderer {
    typealias RSIStyle = LineStyle
    typealias Calculator = RSICalculator
    
    private let period: Int
    private let style: RSIStyle
    let calculator: RSICalculator?
    
    private let lineLayer = CAShapeLayer()
    
    init(period: Int, style: RSIStyle) {
        self.period = period
        self.style = style
        self.calculator = RSICalculator(period: period)
        // 设置线条宽度和填充色
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
        let viewPort = context.viewPort
        
        // 设置MA线颜色
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
            let x = layout.minX(at: idx) + candleStyle.width * 0.5
            // 计算点的y坐标（基于MA值）
            let y = layout.minY(for: value, viewPort: viewPort)
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

//final class RSIRenderer: IndicatorRenderer {
//    
//    private var styleManager: StyleManager { .shared }
//    private let lineWidth = 1 / UIScreen.main.scale
//        
//    var transformer: Transformer?
//    
//    typealias Item = IndicatorData
//        
//    var type: Indicator { .rsi }
//    
//    init() {
//    }
//    
//    func draw(in layer: CALayer, data: RenderData<Item>) {
//        transformer?.dataBounds.combine(other: .init(max: 70, min: 30))
//        guard let transformer = transformer else { return }
//        
//        let rect = transformer.viewPort
//        let candleStyle = styleManager.candleStyle
//        let visibleItems = data.visibleItems
//        guard let last = visibleItems.last else { return }
//        let indicatorData = data.selectedItem ?? last
//        
//        let sublayer = CALayer()
//        sublayer.contentsScale = UIScreen.main.scale
//        sublayer.frame = rect
//        layer.addSublayer(sublayer)
//        
//        // MARK: - 网格线（列）
//        drawColumnBackground(in: layer, viewPort: transformer.viewPort)
//       
//        // MARK: - 标题
//        let attrText = NSMutableAttributedString()
//        
//        for key in type.keys {
//            guard let indicatorStyle = styleManager.indicatorStyle(for: key, type: TrackStyle.self),
//                  let value = indicatorData.indicator(forKey: key) as? Double else {
//                return
//            }
//
//            let span = NSAttributedString(
//                string: "\(key):\(styleManager.format(value: value))  ",
//                attributes: [
//                    .foregroundColor: indicatorStyle.strokeColor,
//                    .font: UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
//                ]
//            )
//            attrText.append(span)
//        }
//        let legendLayer = CATextLayer()
//        legendLayer.contentsScale = UIScreen.main.scale
//        legendLayer.alignmentMode = .left
//        legendLayer.string = attrText
//        let size = legendLayer.preferredFrameSize()
//        legendLayer.frame = CGRect(x: 12, y: rect.minY + 8, width: size.width, height: size.height)
//        layer.addSublayer(legendLayer)
//        
//        // MARK: - 超买和超卖区域
//        let oby = transformer.yAxis(for: 70)
//        let osy = transformer.yAxis(for: 30)
//        let minX = transformer.xAxis(at: 0) + candleStyle.width * 0.5
//        let maxX = transformer.xAxis(at: visibleItems.count - 1) + candleStyle.width * 0.5
//        let overRect = CGRect(x: minX, y: oby, width: maxX - minX, height: osy - oby)
//        
//        let overAreaShape = CAShapeLayer()
//        overAreaShape.fillColor = UIColor.systemBlue.withAlphaComponent(0.1).cgColor
//        overAreaShape.strokeColor = UIColor.clear.cgColor
//        overAreaShape.path = UIBezierPath(rect: overRect).cgPath
//        sublayer.addSublayer(overAreaShape)
//        
//        let overDashLine = CAShapeLayer()
//        overDashLine.lineWidth = 1
//        overDashLine.lineDashPattern = [2, 2]
//        overDashLine.strokeColor = UIColor.systemBlue.withAlphaComponent(0.8).cgColor
//        let overDashLinePath = UIBezierPath()
//        overDashLinePath.move(to: CGPoint(x: overRect.minX, y: overRect.minY))
//        overDashLinePath.addLine(to: CGPoint(x: overRect.maxX, y: overRect.minY))
//        overDashLinePath.move(to: CGPoint(x: overRect.minX, y: overRect.maxY))
//        overDashLinePath.addLine(to: CGPoint(x: overRect.maxX, y: overRect.maxY))
//        overDashLine.path = overDashLinePath.cgPath
//        sublayer.addSublayer(overDashLine)
//        
//        // MARK: - 折线图
//        for key in type.keys {
//            guard let indicatorStyle = styleManager.indicatorStyle(for: key, type: TrackStyle.self) else {
//                return
//            }
//            let indicatorLayer = CAShapeLayer()
//            indicatorLayer.contentsScale = UIScreen.main.scale
//            indicatorLayer.lineWidth = 1
//            indicatorLayer.fillColor = UIColor.clear.cgColor
//            indicatorLayer.strokeColor = indicatorStyle.strokeColor.cgColor
//            
//            let path = UIBezierPath()
//            var hasStartPoint = false
//            for (idx, item) in visibleItems.enumerated() {
//                guard let value = item.indicator(forKey: key) as? Double else {
//                    continue
//                }
//                // 计算 x 坐标
//                let x = transformer.xAxis(at: idx) + candleStyle.width * 0.5
//                let y = transformer.yAxis(for: value)
//                let point = CGPoint(x: x, y: y)
//                
//                if !hasStartPoint {
//                    path.move(to: point)
//                    hasStartPoint = true
//                } else {
//                    path.addLine(to: point)
//                }
//            }
//            
//            indicatorLayer.path = path.cgPath
//            sublayer.addSublayer(indicatorLayer)
//        }
//        
//        // MARK: - 边界线
//        let bottomLineLayer = CAShapeLayer()
//        bottomLineLayer.lineWidth = lineWidth
//        bottomLineLayer.fillColor = UIColor.clear.cgColor
//        bottomLineLayer.strokeColor = UIColor.separator.cgColor
//        let bottomLinePath = UIBezierPath()
//        bottomLinePath.move(to: CGPoint(x: 0, y: rect.maxY - lineWidth))
//        bottomLinePath.addLine(to: CGPoint(x: layer.bounds.maxX, y: rect.maxY - lineWidth))
//        bottomLineLayer.path = bottomLinePath.cgPath
//        layer.addSublayer(bottomLineLayer)
//    }
//}
//
