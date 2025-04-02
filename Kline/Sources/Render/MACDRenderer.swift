//
//  MACDRenderer.swift
//  KLine
//
//  Created by iya on 2025/4/1.
//

import UIKit

final class MACDRenderer: IndicatorRenderer {
    
    private var styleManager: StyleManager { .shared }
    
    var transformer: Transformer?
    
    var type: IndicatorType { .macd }
    
    typealias Item = IndicatorData
    
    func draw(in layer: CALayer, data: RenderData<IndicatorData>) {
        guard let transformer = transformer,
              case let .macd(shortPeriod, longPeriod, signalPeriod) = type.keys[0] else {
            return
        }
        let rect = transformer.viewPort
        let candleStyle = styleManager.candleStyle
        let visibleItems = data.visibleItems
        
        guard let item = data.selectedItem ?? visibleItems.last else { return }
        let key = type.keys[0]
        let indicatorValues = data.visibleItems.map {
            $0.indicator(forKey: key) as? MACDIndicatorValue
        }
        guard let selectedValue = item.indicator(forKey: key) as? MACDIndicatorValue else {
            return
        }
        
        let sublayer = CAShapeLayer()
        sublayer.frame = rect
        sublayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(sublayer)
        
        // MARK: - 网格线（列）
        drawColumnBackground(in: layer, viewPort: transformer.viewPort)
        
        // MARK: - 柱状图
        for (idx, value) in indicatorValues.enumerated() {
            guard let value else { continue }
            let shape = CAShapeLayer()
            shape.contentsScale = UIScreen.main.scale
            shape.strokeColor = UIColor.clear.cgColor
            let x = transformer.xAxis(at: idx)
            var fillColor = KLineTrend.up.color
            if idx > 0, let previousValue = indicatorValues[idx - 1],
               value.histogram < previousValue.histogram {
                fillColor = KLineTrend.down.color
            }
            shape.fillColor = fillColor
            
            let y1 = transformer.yAxis(for: value.histogram > 0 ? value.histogram : 0)
            let y2 = transformer.yAxis(for: value.histogram > 0 ? 0 : value.histogram)
            let rect = CGRect(x: x, y: y1, width: candleStyle.width, height: y2 - y1)
            let path = UIBezierPath(rect: rect)
            shape.path = path.cgPath
            sublayer.addSublayer(shape)
        }
        
        
        // MARK: - 折线图
        let drawLine: (UIColor, [Double?]) -> Void = { color, values in
            let indicatorLayer = CAShapeLayer()
            indicatorLayer.contentsScale = UIScreen.main.scale
            indicatorLayer.lineWidth = 1
            indicatorLayer.fillColor = UIColor.clear.cgColor
            indicatorLayer.strokeColor = color.cgColor
            
            let path = UIBezierPath()
            var hasStartPoint = false
            for (idx, value) in values.enumerated() {
                guard let value else { continue }
                // 计算 x 坐标
                let x = transformer.xAxis(at: idx) + candleStyle.width * 0.5
                let y = transformer.yAxis(for: value)
                let point = CGPoint(x: x, y: y)
                
                if !hasStartPoint {
                    path.move(to: point)
                    hasStartPoint = true
                } else {
                    path.addLine(to: point)
                }
            }
            
            indicatorLayer.path = path.cgPath
            sublayer.addSublayer(indicatorLayer)
        }
        
        drawLine(UIColor.systemPink, indicatorValues.map(\.?.macd))
        drawLine(UIColor.systemOrange, indicatorValues.map(\.?.signal))
        
        // MARK: - 标题
        let attrText = NSMutableAttributedString()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.1
        let font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        let macdText = NSAttributedString(
            string: "MACD:\(styleManager.format(value: selectedValue.histogram))  ",
            attributes: [
                .foregroundColor: UIColor.systemPurple.cgColor,
                .font: font,
                .paragraphStyle: paragraphStyle
            ]
        )
        attrText.append(macdText)
        let difText = NSAttributedString(
            string: "DIF:\(styleManager.format(value: selectedValue.macd))  ",
            attributes: [
                .foregroundColor: UIColor.systemPink.cgColor,
                .font: font,
                .paragraphStyle: paragraphStyle
            ]
        )
        attrText.append(difText)
        let deaText = NSAttributedString(
            string: "DEA:\(styleManager.format(value: selectedValue.signal))  ",
            attributes: [
                .foregroundColor: UIColor.systemOrange.cgColor,
                .font: font,
                .paragraphStyle: paragraphStyle
            ]
        )
        attrText.append(deaText)
        
        let legendLayer = CATextLayer()
        legendLayer.contentsScale = UIScreen.main.scale
        legendLayer.alignmentMode = .center
        legendLayer.string = attrText
        let size = legendLayer.preferredFrameSize()
        legendLayer.frame = CGRect(x: 12, y: rect.minY + 8, width: size.width, height: size.height)
        layer.addSublayer(legendLayer)
    }
}
