//
//  XAxisRenderer.swift
//  KLine
//
//  Created by iya on 2025/4/24.
//

import UIKit

final class XAxisRenderer: Renderer {
    
    var id: some Hashable { ObjectIdentifier(XAxisRenderer.self) }
    private let lineLayer = CAShapeLayer()
    
    init() {
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.lineWidth = 1 / UIScreen.main.scale
        lineLayer.zPosition = -10
    }
    
    func install(to layer: CALayer) {
        layer.addSublayer(lineLayer)
    }
    
    func uninstall(from layer: CALayer) {
        lineLayer.removeFromSuperlayer()
    }
    
    func draw(in layer: CALayer, context: Context) {
        let rect = layer.bounds
        lineLayer.strokeColor = UIColor.systemGray5.cgColor
        
        let gridColumns = 6
        let columnWidth = rect.width / CGFloat(gridColumns - 1)
        
        let path = CGMutablePath()
        for idx in (1..<gridColumns - 1) {
            let x = CGFloat(idx) * columnWidth
            let start = CGPoint(x: x, y: context.groupFrame.minY)
            let end = CGPoint(x: x, y: context.groupFrame.maxY)
            path.move(to: start)
            path.addLine(to: end)
        }
        
        path.move(to: CGPoint(x: 0, y: context.groupFrame.maxY))
        path.addLine(to: CGPoint(x: context.groupFrame.maxX, y: context.groupFrame.maxY))
        
        lineLayer.path = path
    }
}
