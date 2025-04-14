//
//  EMARenderer.swift
//  KLineDemo
//
//  Created by iya on 2024/11/6.
//

import UIKit

final class EMARenderer: IndicatorRenderer {
    
    private var styleManager: StyleManager { .shared }
        
    var transformer: Transformer?
    
    typealias Item = IndicatorData
        
    var type: IndicatorType { .ema }
    
    init() {
    }
    
    func draw(in layer: CALayer, data: RenderData<Item>) {
        guard let transformer = transformer else { return }
        let rect = transformer.viewPort
        let candleStyle = styleManager.candleStyle
        let visibleItems = data.visibleItems
        
        let sublayer = CAShapeLayer()
        sublayer.frame = rect
        sublayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(sublayer)
        
        for key in type.keys {
            guard let indicatorStyle = styleManager.indicatorStyle(
                for: key,
                type: TrackStyle.self
            ) else {
                return
            }
            let indicatorLayer = CAShapeLayer()
            indicatorLayer.contentsScale = UIScreen.main.scale
            indicatorLayer.lineWidth = 1
            indicatorLayer.fillColor = UIColor.clear.cgColor
            indicatorLayer.strokeColor = indicatorStyle.strokeColor.cgColor
            
            let path = UIBezierPath()
            var hasStartPoint = false
            for (idx, item) in visibleItems.enumerated() {
                guard let value = item.indicator(forKey: key) as? Double else {
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
            sublayer.addSublayer(indicatorLayer)
        }
    }
}

