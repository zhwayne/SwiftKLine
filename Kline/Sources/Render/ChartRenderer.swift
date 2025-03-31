//
//  ChartRenderer.swift
//  KLineDemo
//
//  Created by iya on 2024/11/1.
//

import UIKit

/// 渲染数据
@dynamicMemberLookup
struct RenderData<T> {
    let items: [T]
    let visibleRange: Range<Int>
    
    init(items: [T], visibleRange: Range<Int>) {
        self.items = items
        self.visibleRange = visibleRange
    }

    var visibleItems: [T] { Array(items[visibleRange]) }
    var itemType: Any.Type { T.self } // 直接反射泛型类型
    
    // 动态属性存储
    private var dynamicProperties: [String: Any] = [:]
    
    // 动态成员下标
    subscript<U>(dynamicMember key: String) -> U? {
        get { dynamicProperties[key] as? U }
        set { dynamicProperties[key] = newValue }
    }
}


/// 定义绘制器协议 ChartRenderer，每种 Renderer 单独负责一种绘制任务，KLineView 通过聚
/// 合多个 Renderer 来实现多种绘制效果。
@MainActor protocol ChartRenderer: AnyObject {
    
    associatedtype Item
                
    var transformer: Transformer? { get set }
    
    func draw(in layer: CALayer, data: RenderData<Item>)
}

extension ChartRenderer {
    
    func drawColumnBackground(in layer: CALayer, viewPort: CGRect) {
        let rect = CGRectMake(0, viewPort.minY, layer.bounds.width, viewPort.height)
        // (不包含第一列和最后一列)
        let gridLayer = CAShapeLayer()
        gridLayer.fillColor = UIColor.clear.cgColor
        gridLayer.strokeColor = UIColor.systemFill.cgColor
        gridLayer.lineWidth = 1 / UIScreen.main.scale
        gridLayer.contentsScale = UIScreen.main.scale
        
        let gridColumns = 6
        let columnWidth = rect.width / CGFloat(gridColumns - 1)
        
        let path = UIBezierPath()
        for idx in (1..<gridColumns - 1) {
            let x = CGFloat(idx) * columnWidth
            let start = CGPoint(x: x, y: rect.minY)
            let end = CGPoint(x: x, y: rect.maxY)
            path.move(to: start)
            path.addLine(to: end)
        }
        
        gridLayer.path = path.cgPath
        layer.addSublayer(gridLayer)
    }
}
