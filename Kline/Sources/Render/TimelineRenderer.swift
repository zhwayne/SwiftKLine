//
//  TimelineRenderer.swift
//  KLineDemo
//
//  Created by iya on 2024/11/7.
//

import UIKit

final class TimelineRenderer: ChartRenderer {
    
    private var styleManager: StyleManager { .shared }
        
    var transformer: Transformer?
    
    private let dateLayers: [CATextLayer]
    private let lineLayer = CAShapeLayer()
    private let lineWidth = 1 / UIScreen.main.scale
    private let dateFormatter = DateFormatter()
    
    typealias Item = KLineItem
    
    init() {
        dateLayers = (0..<6).map({ idx in
            let label = CATextLayer()
            label.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular) as CTFont
            label.fontSize = 10
            label.alignmentMode = .center
            label.contentsScale = UIScreen.main.scale
            return label
        })
        
        dateFormatter.dateFormat = "MM/dd HH:mm"
    }
   
    func draw(in layer: CALayer, data: RenderData<KLineItem>) {
        guard let transformer = transformer else { return }
        let rect = layer.bounds
        
        // 时间 label 位置固定
        let labelCount = dateLayers.count
        let labelWidth = rect.width / CGFloat(labelCount - 1)
       
        for idx in (0..<labelCount) {
            let label = dateLayers[idx]
            label.foregroundColor = UIColor.secondaryLabel.cgColor
            
            if let index = transformer.indexOfVisibleItem(xAxis: label.position.x) {
                let item = data.items[index]
                let date = Date(timeIntervalSince1970: TimeInterval(item.timestamp))
                let timeString = dateFormatter.string(from: date)
                label.string = timeString
            } else {
                label.string = nil
            }
            
            let size = label.preferredFrameSize()
            label.bounds = CGRect(x: 0, y: 0, width: labelWidth - 4, height: size.height)
            label.position = CGPoint(x: CGFloat(idx) * labelWidth, y: rect.midY)
            
            layer.addSublayer(label)
        }
        
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: 0, y: lineWidth))
        linePath.addLine(to: CGPoint(x: rect.maxX, y: lineWidth))
        linePath.move(to: CGPoint(x: 0, y: rect.height - lineWidth))
        linePath.addLine(to: CGPoint(x: rect.maxX, y: rect.height - lineWidth))

        lineLayer.path = linePath.cgPath
        lineLayer.lineWidth = lineWidth
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.strokeColor = UIColor.separator.cgColor
        layer.addSublayer(lineLayer)
    }
}
