//
//  TimeSeriesRenderer.swift
//  SwiftKLine
//
//  Created by iya on 2024/11/7.
//

import UIKit

/// Renders a high-performance intraday time series line with optional fill.
@MainActor
final class TimeSeriesRenderer: Renderer {
    
    var id: some Hashable { ObjectIdentifier(TimeSeriesRenderer.self) }
    private var style: TimeSeriesStyle
    private let lineLayer = CAShapeLayer()
    private let fillLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()
    private let lineWidth = 1 / UIScreen.main.scale
    
    private var cachedVisibleRange: Range<Int> = 0..<0
    private var cachedViewPort: CGRect = .null
    private var cachedLayoutFrame: CGRect = .null
    private var cachedBounds: (min: Double, max: Double) = (.nan, .nan)
    private var cachedLastVisibleTimestamp: Int?
    private var cachedLastVisibleClosing: Double = .nan
    
    init(style: TimeSeriesStyle) {
        self.style = style
        configureLayers()
    }
    
    func updateStyle(_ style: TimeSeriesStyle) {
        self.style = style
        applyStyle()
    }
    
    func install(to layer: CALayer) {
        fillLayer.frame = layer.bounds
        lineLayer.frame = layer.bounds
        borderLayer.frame = layer.bounds
        layer.addSublayer(fillLayer)
        layer.addSublayer(lineLayer)
        layer.addSublayer(borderLayer)
    }
    
    func uninstall(from layer: CALayer) {
        borderLayer.removeFromSuperlayer()
        lineLayer.removeFromSuperlayer()
        fillLayer.removeFromSuperlayer()
    }
    
    func draw(in layer: CALayer, context: Context) {
        fillLayer.frame = layer.bounds
        lineLayer.frame = layer.bounds
        borderLayer.frame = layer.bounds
        borderLayer.strokeColor = style.borderColor.cgColor
        borderLayer.path = makeBorderPath(in: layer.bounds, groupFrame: context.groupFrame)
        
        let layout = context.layout
        let visibleRange = context.visibleRange
        let visibleItems = context.visibleItems
        let latestItem = visibleItems.last
        let dataChanged: Bool
        if let latestItem {
            dataChanged =
                cachedLastVisibleTimestamp != latestItem.timestamp ||
                cachedLastVisibleClosing != latestItem.closing
        } else {
            dataChanged = cachedLastVisibleTimestamp != nil
        }
        let viewPort = context.viewPort
        let layoutFrame = layout.frameOfVisibleRange
        let bounds = layout.dataBounds
        let needsPathUpdate =
            cachedVisibleRange != visibleRange ||
            cachedViewPort != viewPort ||
            cachedLayoutFrame != layoutFrame ||
            cachedBounds.min.isNaN || cachedBounds.max.isNaN ||
            cachedBounds.min != bounds.min ||
            cachedBounds.max != bounds.max ||
            dataChanged
        if needsPathUpdate {
            updatePaths(context: context)
            cachedVisibleRange = visibleRange
            cachedViewPort = viewPort
            cachedLayoutFrame = layoutFrame
            cachedBounds = (bounds.min, bounds.max)
            cachedLastVisibleTimestamp = latestItem?.timestamp
            cachedLastVisibleClosing = latestItem?.closing ?? .nan
        }
    }
    
    func dataBounds(context: Context) -> MetricBounds {
        let visibleItems = context.visibleItems
        guard !visibleItems.isEmpty else { return .empty }
        var minValue = Double.greatestFiniteMagnitude
        var maxValue = -Double.greatestFiniteMagnitude
        for item in visibleItems {
            minValue = min(minValue, item.lowest, item.closing)
            maxValue = max(maxValue, item.highest, item.closing)
        }
        return MetricBounds(min: minValue, max: maxValue)
    }
}

private extension TimeSeriesRenderer {
    
    func configureLayers() {
        lineLayer.lineWidth = 1
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.lineJoin = .round
        lineLayer.lineCap = .round
        lineLayer.zPosition = 1
        fillLayer.fillColor = style.fillColor.cgColor
        fillLayer.strokeColor = UIColor.clear.cgColor
        fillLayer.zPosition = 0
        borderLayer.lineWidth = lineWidth
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.zPosition = 2
        applyStyle()
    }
    
    func applyStyle() {
        lineLayer.strokeColor = style.lineColor.cgColor
        fillLayer.fillColor = style.fillColor.cgColor
        borderLayer.strokeColor = style.borderColor.cgColor
    }
    
    func makeBorderPath(in bounds: CGRect, groupFrame: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: groupFrame.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: groupFrame.minY))
        path.move(to: CGPoint(x: 0, y: groupFrame.maxY - lineWidth * 0.5))
        path.addLine(to: CGPoint(x: bounds.maxX, y: groupFrame.maxY - lineWidth * 0.5))
        return path
    }
    
    func updatePaths(context: Context) {
        let layout = context.layout
        let viewPort = context.viewPort
        let visibleItems = context.visibleItems
        guard !visibleItems.isEmpty else {
            lineLayer.path = nil
            fillLayer.path = nil
            return
        }
        let candleStyle = context.configuration.candleStyle
        let linePath = CGMutablePath()
        let fillPath = CGMutablePath()
        var firstPoint: CGPoint?
        var lastPoint: CGPoint?
        for (idx, item) in visibleItems.enumerated() {
            let centerX = layout.minX(at: idx) + candleStyle.width * 0.5
            let priceY = layout.minY(for: item.closing, viewPort: viewPort)
            let point = CGPoint(x: centerX, y: priceY)
            if let _ = firstPoint {
                linePath.addLine(to: point)
                fillPath.addLine(to: point)
            } else {
                linePath.move(to: point)
                fillPath.move(to: point)
                firstPoint = point
            }
            lastPoint = point
        }
        if let firstPoint, let lastPoint {
            fillPath.addLine(to: CGPoint(x: lastPoint.x, y: viewPort.maxY))
            fillPath.addLine(to: CGPoint(x: firstPoint.x, y: viewPort.maxY))
            fillPath.closeSubpath()
        }
        lineLayer.path = linePath
        fillLayer.path = fillPath
    }
}
