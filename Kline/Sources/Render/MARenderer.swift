//
//  MARenderer.swift
//  KLineDemo
//
//  Created by iya on 2024/11/1.
//

import UIKit

final class MARenderer: IndicatorRenderer {
    
    private var styleManager: StyleManager { .shared }

    var transformer: Transformer?
    
    typealias Item = IndicatorData
    
    var type: IndicatorType { .ma }
    
    init() {
    }

    func draw(in layer: CALayer, data: RenderData<IndicatorData>) {
        guard let transformer = transformer else { return }
        let candleStyle = styleManager.candleStyle
        let visibleItems = data.visibleItems
        let rect = transformer.viewPort
        
        let sublayer = CAShapeLayer()
        sublayer.frame = rect
        sublayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(sublayer)
        
        for key in type.keys {
            let indicatorStyle = styleManager.indicatorStyle(for: key)
            let indicatorLayer = CAShapeLayer()
            indicatorLayer.contentsScale = UIScreen.main.scale
            indicatorLayer.lineWidth = indicatorStyle.lineWidth
            indicatorLayer.fillColor = indicatorStyle.fillColor.cgColor
            indicatorLayer.strokeColor = indicatorStyle.strokeColor.cgColor
            
            let path = UIBezierPath()
            var hasStartPoint = false
            for (idx, item) in visibleItems.enumerated() {
                guard let value = item.indicator(forKey: key)?.doubeValue else {
                    continue
                }
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
            if indicatorLayer.superlayer == nil {
                sublayer.addSublayer(indicatorLayer)
            }
        }
    }
}
