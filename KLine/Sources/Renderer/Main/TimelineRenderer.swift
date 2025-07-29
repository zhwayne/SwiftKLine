//
//  TimelineRenderer.swift
//  KLineDemo
//
//  Created by iya on 2024/11/7.
//

import UIKit

final class TimelineRenderer: Renderer {
    
    var id: some Hashable { ObjectIdentifier(TimelineRenderer.self) }
    private let style: TimelineStyle
    private var textLayers: [CATextLayer] = []
    private let borderLayer = CAShapeLayer()
    private let dateFormatter = DateFormatter()
    private let lineWidth = 1 / UIScreen.main.scale
    
    init(style: TimelineStyle) {
        self.style = style
        dateFormatter.dateFormat = "MM-dd HH:mm"
        textLayers = (0..<6).map({ idx in
            let label = CATextLayer()
            label.font = style.font as CTFont
            label.fontSize = style.font.pointSize
            label.alignmentMode = .center
            label.contentsScale = UIScreen.main.scale
            return label
        })
        borderLayer.lineWidth = lineWidth
        borderLayer.fillColor = UIColor.clear.cgColor
    }
    
    func install(to layer: CALayer) {
        textLayers.forEach { layer.addSublayer($0) }
        layer.addSublayer(borderLayer)
    }
    
    func uninstall(from layer: CALayer) {
        textLayers.forEach { $0.removeFromSuperlayer() }
        borderLayer.removeFromSuperlayer()
        textLayers = []
    }
    
    func draw(in layer: CALayer, context: Context) {
        let layout = context.layout
        let viewPort = context.viewPort
        let items = context.items
        let groupFrame = context.groupFrame
        
        borderLayer.strokeColor = UIColor.systemGray3.cgColor
        let borderPath = CGMutablePath()
        borderPath.move(to: CGPoint(x: 0, y: groupFrame.minY))
        borderPath.addLine(to: CGPoint(x: layer.bounds.maxX, y: groupFrame.minY))
        borderPath.move(to: CGPoint(x: 0, y: groupFrame.maxY - lineWidth * 0.5))
        borderPath.addLine(to: CGPoint(x: layer.bounds.maxX, y: groupFrame.maxY - lineWidth * 0.5))
        borderLayer.path = borderPath
        
        // 时间 label 位置固定
        let labelCount = textLayers.count
        let rect = layer.bounds
        let labelWidth = rect.width / CGFloat(labelCount - 1)
        
        for idx in (0..<labelCount) {
            let label = textLayers[idx]
            let position = CGPoint(x: CGFloat(idx) * labelWidth, y: viewPort.midY)
            
            if let index = layout.indexInViewPort(on: position.x) {
                let item = items[index]
                let date = Date(timeIntervalSince1970: TimeInterval(item.timestamp))
                let timeString = dateFormatter.string(from: date)
                label.string = timeString
                label.foregroundColor = style.textColor.cgColor
            } else {
                label.string = nil
            }
            
            let size = label.preferredFrameSize()
            label.bounds = CGRect(x: 0, y: 0, width: labelWidth - 4, height: size.height)
            label.position = CGPoint(x: CGFloat(idx) * labelWidth, y: viewPort.midY)
        }
    }
}
