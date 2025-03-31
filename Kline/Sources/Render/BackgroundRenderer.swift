//
//  BackgroundRenderer.swift
//  KLine
//
//  Created by iya on 2025/3/25.
//

import UIKit

final class BackgroundRenderer: ChartRenderer {
    
    private var styleManager: StyleManager { .shared }
    
    var transformer: Transformer?
    
    typealias Item = KLineItem
    
    init() {
    }

    func draw(in layer: CALayer, data: RenderData<KLineItem>) {
        guard let transformer = transformer else { return }
        let viewPort = transformer.viewPort
        let rect = CGRectMake(0, viewPort.minY, layer.bounds.width, viewPort.height)
        
        let sublayer = CALayer()
        sublayer.frame = rect
        sublayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(sublayer)
       
        let gridLayer = CAShapeLayer()
        gridLayer.lineWidth = 1 / UIScreen.main.scale
        gridLayer.contentsScale = UIScreen.main.scale
        gridLayer.fillColor = UIColor.clear.cgColor
        gridLayer.strokeColor = UIColor.systemFill.cgColor
        sublayer.addSublayer(gridLayer)
       
        let gridColumns = 6
        let columnWidth = rect.width / CGFloat(gridColumns - 1)
        
        // MARK: - 绘制列
        // (不包含第一列和最后一列)
        let path = UIBezierPath()
        for idx in (1..<gridColumns - 1) {
            let x = CGFloat(idx) * columnWidth
            let start = CGPoint(x: x, y: 0)
            let end = CGPoint(x: x, y: layer.bounds.height)
            path.move(to: start)
            path.addLine(to: end)
        }

        // MARK: - 绘制行
        // 生成等分价格线
        let dataBounds = transformer.dataBounds
        let (stepSize, _) = calculateGridSteps(
            min: dataBounds.min,
            max: dataBounds.max,
            maxLines: 7
        )
        
        guard stepSize > 0 else { return }

        var currentValue = floor(dataBounds.min / stepSize) * stepSize
        var y: CGFloat = rect.maxY
        while y > 0 {
            defer {
                currentValue += stepSize
            }
            y = transformer.yAxis(for: currentValue)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            
            // 添加 文本显示
            let textLayer = CATextLayer()
            textLayer.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular) as CTFont
            textLayer.fontSize = 10
            textLayer.foregroundColor = UIColor.secondaryLabel.cgColor
            textLayer.alignmentMode = .center
            textLayer.contentsScale = UIScreen.main.scale
            textLayer.string = styleManager.format(value: currentValue)
            let textSize = textLayer.preferredFrameSize()
            let textOrigin = CGPoint(
                x: rect.width - 12 - textSize.width,
                y: y - textSize.height - 2
            )
            textLayer.frame = CGRect(origin: textOrigin, size: textSize)
            textLayer.zPosition = 1
            layer.addSublayer(textLayer)
        }
        
        gridLayer.path = path.cgPath
    }
    
    // 智能网格步长计算
    private func calculateGridSteps(min: Double, max: Double, maxLines: Int) -> (step: Double, count: Int) {
        let range = max - min
        guard range > 0, maxLines > 0 else { return (0, 0) }
        
        // 计算初始估算步长
        let roughStep = range / Double(maxLines)
        
        // 计算数量级
        let magnitude = pow(10, floor(log10(roughStep)))
        let normalizedStep = roughStep / magnitude
        
        // 选择最接近的标准步长
        let niceSteps: [Double] = [0.1, 0.2, 0.25, 0.5, 1.0, 2.0, 2.5, 5.0, 10.0]
        let chosenStep = niceSteps.first { $0 >= normalizedStep } ?? normalizedStep
        
        let actualStep = chosenStep * magnitude
        let stepCount = Int(ceil(range / actualStep))
        
        return (actualStep, Swift.min(stepCount, maxLines))
    }
}
