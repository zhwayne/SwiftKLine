//
//  YAxisRenderer.swift
//  SwiftKLine
//
//  Created by iya on 2025/4/25.
//

import UIKit

final class YAxisRenderer: Renderer {
        
    var id: some Hashable { ObjectIdentifier(YAxisRenderer.self) }
    private let lineLayer = CAShapeLayer()
    private var textLayerQueue = [CATextLayer]()
    private let priceFormatter = PriceFormatter()
    
    init() {
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.lineWidth = 1 / UIScreen.main.scale
        lineLayer.zPosition = -1
    }
    
    func install(to layer: CALayer) {
        layer.addSublayer(lineLayer)
    }
    
    func uninstall(from layer: CALayer) {
        lineLayer.removeFromSuperlayer()
        textLayerQueue.forEach { $0.removeFromSuperlayer() }
        textLayerQueue = []
    }
    
    func draw(in layer: CALayer, context: Context) {
        let layout = context.layout
        let viewPort = context.viewPort
        let groupFrame = context.groupFrame
        let rect = layer.bounds
        lineLayer.strokeColor = UIColor.systemGray5.cgColor
        
        let path = CGMutablePath()
        let values = layout.niceValues(in: viewPort, groupFrame: groupFrame)
        
        let count = values.count - textLayerQueue.count
        if count > 0 {
            (0..<count).forEach { _ in
                let textLayer = makeTextLayer()
                textLayerQueue.append(textLayer)
                layer.addSublayer(textLayer)
            }
        } else if count < 0 {
            (0..<abs(count)).forEach { _ in
                let textLayer = textLayerQueue.popLast()
                textLayer?.removeFromSuperlayer()
            }
        }
        
        for (value, textLayer) in zip(values, textLayerQueue) {
            let start = CGPoint(x: 0, y: value.y)
            let end = CGPoint(x: rect.maxX, y: value.y)
            path.move(to: start)
            path.addLine(to: end)
            
            textLayer.foregroundColor = UIColor.secondaryLabel.cgColor
            textLayer.string = priceFormatter.format(value.value as NSNumber)
            let textSize = textLayer.preferredFrameSize()
            let textOrigin = CGPoint(
                x: rect.width - 12 - textSize.width,
                y: value.y - textSize.height - 2
            )
            textLayer.frame = CGRect(origin: textOrigin, size: textSize)
        }
        lineLayer.path = path
    }
    
    private func makeTextLayer() -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular) as CTFont
        textLayer.fontSize = 10
        textLayer.alignmentMode = .center
        textLayer.contentsScale = UIScreen.main.scale
        return textLayer
    }
}
