//
//  CandleRenderer.swift
//  KLineDemo
//
//  Created by iya on 2024/11/1.
//

import UIKit

final class CandleRenderer: ChartRenderer {
    
    private var styleManager: StyleManager { .shared }
    private let lineWidth = 1 / UIScreen.main.scale
    private let priceMarkView = PriceMarkView()
    
    var transformer: Transformer?
        
    typealias Item = KLineItem
    
    init() {
    }
    
    func draw(in layer: CALayer, data: RenderData<KLineItem>) {
        guard let transformer = transformer else { return }
        let viewPort = transformer.viewPort
        let candleStyle = styleManager.candleStyle
        let visibleItems = data.visibleItems
        
        // MARK: - 配置layer和视图属性
        let sublayer = CALayer()
        sublayer.frame = viewPort
        layer.addSublayer(sublayer)
        
        let lineLayer = CAShapeLayer()
        lineLayer.lineWidth = lineWidth
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.strokeColor = UIColor.separator.cgColor
        layer.addSublayer(lineLayer)
        
        let dashLineLayer = CAShapeLayer()
        dashLineLayer.strokeColor = UIColor.label.cgColor
        dashLineLayer.lineWidth = lineWidth
        dashLineLayer.lineDashPattern = [2, 2]
        layer.addSublayer(dashLineLayer)
        
        let upLayer = CAShapeLayer()
        upLayer.fillColor = KLineTrend.up.color
        upLayer.strokeColor = KLineTrend.up.color
        upLayer.lineWidth = 1
        upLayer.contentsScale = UIScreen.main.scale
        sublayer.addSublayer(upLayer)
        
        let downLayer = CAShapeLayer()
        downLayer.fillColor = KLineTrend.down.color
        downLayer.strokeColor = KLineTrend.down.color
        downLayer.lineWidth = 1
        downLayer.contentsScale = UIScreen.main.scale
        sublayer.addSublayer(downLayer)
        
        let priceLineLayer = CAShapeLayer()
        priceLineLayer.lineWidth = 1
        priceLineLayer.strokeColor = UIColor.label.withAlphaComponent(0.8).cgColor
        sublayer.addSublayer(priceLineLayer)
        
        let highestTextLayer = CATextLayer()
        highestTextLayer.foregroundColor = UIColor.label.withAlphaComponent(0.8).cgColor
        highestTextLayer.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular) as CTFont
        highestTextLayer.fontSize = 10
        highestTextLayer.alignmentMode = .center
        highestTextLayer.contentsScale = UIScreen.main.scale
        sublayer.addSublayer(highestTextLayer)
        
        let lowestTextLayer = CATextLayer()
        lowestTextLayer.foregroundColor = UIColor.label.withAlphaComponent(0.8).cgColor
        lowestTextLayer.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular) as CTFont
        lowestTextLayer.fontSize = 10
        lowestTextLayer.alignmentMode = .center
        lowestTextLayer.contentsScale = UIScreen.main.scale
        sublayer.addSublayer(lowestTextLayer)
        
        // MARK: - 顶部线条
        
        let topLinePath = UIBezierPath()
        topLinePath.move(to: CGPoint(x: 0, y: lineWidth))
        topLinePath.addLine(to: CGPoint(x: layer.bounds.maxX, y: lineWidth))
        lineLayer.path = topLinePath.cgPath
        
        // MARK: - 蜡烛图
        let upPath = UIBezierPath()
        let downPath = UIBezierPath()
        for (idx, item) in visibleItems.enumerated() {
            // 计算 x 坐标
            let x = transformer.xAxis(at: idx)
            
            // 计算开盘价和收盘价的 y 坐标
            let openY = transformer.yAxis(for: item.opening)
            let closeY = transformer.yAxis(for: item.closing)
            let y = min(openY, closeY)
            let h = abs(openY - closeY)
            
            let rect = CGRect(x: x, y: y, width: candleStyle.width, height: h)
            let path = UIBezierPath(rect: rect)
            
            // 计算最高价和最低价的 y 坐标
            let highY = transformer.yAxis(for: item.highest)
            let lowY = transformer.yAxis(for: item.lowest)
            
            let centerX = candleStyle.width / 2 + x
            let highestPoint = CGPoint(x: centerX, y: highY)
            let lowestPoint = CGPoint(x: centerX, y: lowY)
            
            path.move(to: highestPoint)
            path.addLine(to: CGPoint(x: centerX, y: y))
            path.move(to: lowestPoint)
            path.addLine(to: CGPoint(x: centerX, y: y + h))
            
            let trend = item.trend
            let candlePath = trend == .down ? downPath : upPath
            candlePath.append(path)
        }
        upLayer.path = upPath.cgPath
        downLayer.path = downPath.cgPath
        
        
        let priceLinePath = UIBezierPath()
        
        // MARK: - 最高价指示
        if let item = visibleItems.max(by: { $0.highest < $1.highest }),
           let index = visibleItems.firstIndex(of: item) {
            let x = transformer.xAxis(at: index) + candleStyle.width * 0.5
            let y = transformer.yAxis(for: item.highest)
            
            let rightSide = (x + transformer.viewPort.origin.x) < layer.bounds.midX
            let startPoint = CGPoint(x: x, y: y)
            let endPoint = CGPoint(x: x + (rightSide ? 30 : -30 ), y: y)
            priceLinePath.move(to: startPoint)
            priceLinePath.addLine(to: endPoint)

            highestTextLayer.string = styleManager.format(value: item.highest)
            
            let textSize = highestTextLayer.preferredFrameSize()
            let textOrigin = CGPoint(
                x: endPoint.x + (rightSide ? 0 : -textSize.width),
                y: y - textSize.height * 0.5
            )
            highestTextLayer.frame = CGRect(origin: textOrigin, size: textSize)
        }
        
        // MARK: - 最低价指示
        if let item = visibleItems.max(by: { $0.lowest > $1.lowest }),
           let index = visibleItems.firstIndex(of: item) {
            let x = transformer.xAxis(at: index) + candleStyle.width * 0.5
            let y = transformer.yAxis(for: item.lowest)
            
            let rightSide = (x + transformer.viewPort.origin.x) < layer.bounds.midX
            let startPoint = CGPoint(x: x, y: y)
            let endPoint = CGPoint(x: x + (rightSide ? 30 : -30 ), y: y)
            
            priceLinePath.move(to: startPoint)
            priceLinePath.addLine(to: endPoint)
            
            if priceLineLayer.superlayer == nil {
                sublayer.addSublayer(priceLineLayer)
            }

            lowestTextLayer.string = styleManager.format(value: item.lowest)
            let textSize = lowestTextLayer.preferredFrameSize()
            let textOrigin = CGPoint(
                x: endPoint.x + (rightSide ? 0 : -textSize.width),
                y: y - textSize.height * 0.5
            )
            lowestTextLayer.frame = CGRect(origin: textOrigin, size: textSize)
        }
        
        priceLineLayer.path = priceLinePath.cgPath
        
        // MARK: - 最新价(悬浮在 layer 之上)
        if let item = data.items.last {
            let minY = transformer.yAxis(for: transformer.dataBounds.max)
            let maxY = transformer.yAxis(for: transformer.dataBounds.min)
            let rect = CGRectMake(0, viewPort.minY, layer.bounds.width, viewPort.height)
            var y = transformer.yAxis(for: item.closing)
            y = min(max(y, minY), maxY)
            let index = data.items.count - data.visibleRange.lowerBound - 1
            var x = transformer.xAxisInLayer(at: index)
            if x > rect.maxX { x = 0 }
            let end = CGPoint(x: x, y: y)
            let start = CGPoint(x: rect.width, y: y)
            
            let path = UIBezierPath()
            path.move(to: start)
            path.addLine(to: end)
            dashLineLayer.path = path.cgPath

            priceMarkView.showArrow = end.x == 0
            priceMarkView.label.text = styleManager.format(value: item.closing)
            let indicatorSize = priceMarkView.systemLayoutSizeFitting(rect.size)
            priceMarkView.bounds.size = indicatorSize
            priceMarkView.frame.origin.y = y - indicatorSize.height * 0.5
            priceMarkView.frame.origin.x = start.x - 12 - indicatorSize.width
            if priceMarkView.superview == nil, let view = layer.owningView {
                view.addSubview(priceMarkView)
            }
        }
    }
}
