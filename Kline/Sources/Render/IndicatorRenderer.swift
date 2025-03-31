//
//  IndicatorRenderer.swift
//  KLine
//
//  Created by iya on 2025/3/27.
//

import UIKit

protocol IndicatorRenderer: ChartRenderer {
    
    var type: IndicatorType { get }
}


final class AnyIndicatorRenderer: IndicatorRenderer {
            
    var transformer: Transformer? {
        get { base.transformer }
        set { base.transformer = newValue }
    }
    
    var type: IndicatorType { base.type }
    
    private var base: any IndicatorRenderer
    private let _draw: (CALayer, RenderData<Any>) -> Void
    
    fileprivate init<R: IndicatorRenderer>(_ renderer: R) {
        base = renderer
        _draw = { [unowned renderer] layer, data in
            guard let items = data.items as? [R.Item] else {
                fatalError("Type mismatch. Expected: \(R.Item.self), Actual: \(data.itemType)")
            }
            let concreteData = RenderData(
                items: items,
                visibleRange: data.visibleRange
            )
            renderer.draw(in: layer, data: concreteData)
        }
    }
    
    func draw(in layer: CALayer, data: RenderData<Any>) {
        _draw(layer, data)
    }
}

extension IndicatorRenderer {
    
    func eraseToAnyRenderer() -> AnyIndicatorRenderer {
        AnyIndicatorRenderer(self)
    }
}
