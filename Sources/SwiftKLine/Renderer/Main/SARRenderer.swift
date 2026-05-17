//
//  SARRenderer.swift
//  SwiftKLine
//
//  Created by zhwayne on 2025/8/7.
//

import UIKit

final class SARRenderer: ChartRenderer {
    
    private let priceFormatter = PriceFormatter()
    
    private let rectLayer = CAShapeLayer()

    var id: some Hashable { BuiltInIndicator.sar }

    init() {
        rectLayer.lineWidth = 1
        rectLayer.fillColor = UIColor.clear.cgColor
    }

    func install(to layer: CALayer) {
        layer.addSublayer(rectLayer)
    }
    
    func uninstall(from layer: CALayer) {
        rectLayer.removeFromSuperlayer()
    }
    
    func draw(in layer: CALayer, context: Context) {
        let configuration = context.configuration
        let candleDims = context.candleDimensions
        let layout = context.layout

        let key = SeriesKey.sar
        guard let visibleValues = context.visibleScalarValues(for: key) else {
            return
        }
        let style = configuration.indicatorStyle(for: key, type: LineStyle.self)
        rectLayer.strokeColor = style?.strokeColor.cgColor
        
        let itemWidth = candleDims.itemWidth
        let candleHalfWidth = candleDims.width * 0.5
        let visibleMinX = CGFloat(context.visibleRange.lowerBound) * itemWidth - layout.scrollView.contentOffset.x

        let path = CGMutablePath()
        for (idx, value) in visibleValues.enumerated() {
            guard let value else { continue }
            let x = CGFloat(idx) * itemWidth + visibleMinX + candleHalfWidth
            let y = layout.yPosition(for: value, viewPort: context.viewPort)
            let rect = CGRect(x: x - 2, y: y - 2, width: 4, height: 4)
            path.addRect(rect)
        }
        rectLayer.path = path
    }
    
    func legend(context: Context) -> NSAttributedString? {
        let key = SeriesKey.sar
        let style = context.configuration.indicatorStyle(for: key, type: LineStyle.self)
        guard let values = context.scalarValues(for: key), !values.isEmpty,
              context.currentIndex >= 0,
              context.currentIndex < values.count,
              let value = values[context.currentIndex] else {
            return nil
        }
        let partialResult = NSMutableAttributedString()
        partialResult.append(NSAttributedString(
            string: "\(key.description):\(priceFormatter.format(NSDecimalNumber(floatLiteral: value))) ",
            attributes: [
                .foregroundColor: style?.strokeColor,
                .font: context.configuration.legendFont
            ]
        ))
        return partialResult
    }
    
    func dataBounds(context: Context) -> ValueBounds {
        let visibleValues = context.visibleScalarValues(for: .sar)
        guard let visibleValues else {
            return .empty
        }
        var minValue = Double.greatestFiniteMagnitude
        var maxValue = -Double.greatestFiniteMagnitude
        var hasValue = false
        for value in visibleValues {
            guard let value else { continue }
            hasValue = true
            minValue = Swift.min(minValue, value)
            maxValue = Swift.max(maxValue, value)
        }
        guard hasValue else { return .empty }
        return ValueBounds(min: minValue, max: maxValue)
    }
}
