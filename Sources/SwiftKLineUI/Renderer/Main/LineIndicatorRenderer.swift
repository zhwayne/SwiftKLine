//
//  LineIndicatorRenderer.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2024/11/01.
//

import UIKit
import SwiftKLineCore

/// Draws one or more Double-valued indicator outputs without a custom renderer implementation.
///
/// Only visible values are traversed. Nil or non-finite values break a path, missing series clear stale paths,
/// and missing line styles fall back to the label color.
public final class LineIndicatorRenderer: ChartRenderer {
    private struct ID: Hashable { let keys: [SeriesKey] }
    private let keys: [SeriesKey]
    private let lineLayers: [CAShapeLayer]
    private let priceFormatter = PriceFormatter()
    /// Uses the complete ordered series-key list so renderers with different periods are not reused interchangeably.
    public var id: some Hashable { ID(keys: keys) }

    /// Creates one reusable shape layer per series; keys must match the outputs produced by registered calculators.
    public init(series: [SeriesKey]) {
        self.keys = series
        lineLayers = series.map { _ in
            let layer = CAShapeLayer()
            layer.lineWidth = 1
            layer.fillColor = nil
            return layer
        }
    }

    /// Attaches the reusable line layers to the viewport canvas.
    public func install(to layer: CALayer) { lineLayers.forEach { layer.addSublayer($0) } }
    /// Detaches all line layers owned by this renderer.
    public func uninstall(from layer: CALayer) { lineLayers.forEach { $0.removeFromSuperlayer() } }

    /// Rebuilds visible paths from aligned scalar values and resolves current style colors.
    public func draw(in layer: CALayer, context: ChartContext) {
        let itemWidth = context.candleDimensions.itemWidth
        let origin = CGFloat(context.visibleRange.lowerBound) * itemWidth - context.layout.scrollView.contentOffset.x
        for (key, line) in zip(keys, lineLayers) {
            guard let values = context.visibleScalarValues(for: key) else { line.path = nil; continue }
            line.strokeColor = (context.configuration.indicatorStyle(for: key, type: LineStyle.self)?.strokeColor ?? .label).cgColor
            let path = CGMutablePath()
            var connected = false
            for (offset, value) in values.enumerated() {
                guard let value, value.isFinite else { connected = false; continue }
                let point = CGPoint(x: origin + CGFloat(offset) * itemWidth + context.candleWidth / 2,
                                    y: context.layout.yPosition(for: value, viewPort: context.viewPort))
                if connected { path.addLine(to: point) } else { path.move(to: point) }
                connected = true
            }
            line.path = path
        }
    }

    /// Formats finite values at the selected or last visible index, using each key’s name and optional period.
    public func legend(context: ChartContext) -> NSAttributedString? {
        let result = NSMutableAttributedString()
        for key in keys {
            guard let values = context.scalarValues(for: key), values.indices.contains(context.currentIndex),
                  let value = values[context.currentIndex], value.isFinite else { continue }
            let title = key.name + (key.parameters["period"] ?? "")
            let color = context.configuration.indicatorStyle(for: key, type: LineStyle.self)?.strokeColor ?? .label
            result.append(NSAttributedString(string: "\(title): \(priceFormatter.format(value as NSNumber)) ",
                attributes: [.foregroundColor: color, .font: context.configuration.legendFont]))
        }
        return result
    }

    /// Combines finite visible scalar values into the group’s required value range.
    public func dataBounds(context: ChartContext) -> ValueBounds {
        var result = ValueBounds.empty
        for key in keys {
            guard let values = context.visibleScalarValues(for: key) else { continue }
            for value in values {
                guard let value, value.isFinite else { continue }
                result.merge(other: ValueBounds(min: value, max: value))
            }
        }
        return result
    }
}
