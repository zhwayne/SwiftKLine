//
//  BandRenderer.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/10/22.
//

import SwiftKLineCore
import UIKit

/// Draws one keyed upper/middle/lower channel with reusable line and fill layers.
///
/// The renderer reads ``BandIndicatorValue`` outputs, resolves its color from the complete series key, and
/// merges all three prices into the main-panel value bounds. Missing values split every path so a data gap
/// never connects two non-contiguous windows with a misleading line or filled area.
final class BandRenderer: ChartRenderer {
    private let priceFormatter = PriceFormatter()

    private let upperLayer = CAShapeLayer()
    private let middleLayer = CAShapeLayer()
    private let lowerLayer = CAShapeLayer()
    private let areaLayer = CAShapeLayer()

    /// The exact output identity; changing a channel parameter installs a different renderer.
    var id: some Hashable { key }
    /// The channel series identity, including every calculation parameter.
    let key: SeriesKey

    /// Creates a renderer for one channel key and configures reusable layer defaults.
    ///
    /// - Parameter key: The exact series identity produced by the registered calculator.
    init(key: SeriesKey) {
        self.key = key
        for layer in [upperLayer, middleLayer, lowerLayer] {
            layer.lineWidth = 1
            layer.fillColor = UIColor.clear.cgColor
        }
        areaLayer.strokeColor = UIColor.clear.cgColor
    }

    /// Attaches the reusable fill and line layers to the viewport canvas.
    ///
    /// - Parameter layer: The canvas layer owned by the current renderer group.
    func install(to layer: CALayer) {
        layer.addSublayer(areaLayer)
        layer.addSublayer(upperLayer)
        layer.addSublayer(middleLayer)
        layer.addSublayer(lowerLayer)
    }

    /// Detaches every layer owned by this renderer.
    ///
    /// - Parameter layer: The canvas layer passed to ``install(to:)``.
    func uninstall(from layer: CALayer) {
        areaLayer.removeFromSuperlayer()
        upperLayer.removeFromSuperlayer()
        middleLayer.removeFromSuperlayer()
        lowerLayer.removeFromSuperlayer()
    }

    /// Rebuilds visible channel paths and applies the current line color to every band.
    ///
    /// Only the visible slice is traversed. A nil value closes the current segment for both the line and
    /// the filled area, then the next finite value starts a new segment at its own x position.
    ///
    /// - Parameters:
    ///   - layer: The canvas layer receiving the current frame.
    ///   - context: The coherent candle and indicator snapshot for this drawing pass.
    func draw(in layer: CALayer, context: Context) {
        guard let visibleValues = context.visibleValues(for: key, as: BandIndicatorValue.self) else {
            clearPaths()
            return
        }

        let style = context.appearance.indicatorStyle(for: key, type: LineStyle.self)
        let color = style?.strokeColor ?? .label
        for line in [upperLayer, middleLayer, lowerLayer] {
            line.strokeColor = color.cgColor
        }
        areaLayer.fillColor = color.withAlphaComponent(0.05).cgColor

        let candleDimensions = context.candleDimensions
        let itemWidth = candleDimensions.itemWidth
        let candleHalfWidth = candleDimensions.width * 0.5
        let visibleMinX = CGFloat(context.visibleRange.lowerBound) * itemWidth
            - context.layout.scrollView.contentOffset.x

        let upperPath = CGMutablePath()
        let middlePath = CGMutablePath()
        let lowerPath = CGMutablePath()
        let areaPath = CGMutablePath()

        var upperPoints: [CGPoint] = []
        var lowerPoints: [CGPoint] = []
        var connected = false

        for (offset, value) in visibleValues.enumerated() {
            guard let value else {
                flushAreaSegment(upper: &upperPoints, lower: &lowerPoints, into: areaPath)
                connected = false
                continue
            }

            let x = CGFloat(offset) * itemWidth + visibleMinX + candleHalfWidth
            let upperPoint = CGPoint(
                x: x,
                y: context.layout.yPosition(for: value.upper, viewPort: context.viewPort)
            )
            let middlePoint = CGPoint(
                x: x,
                y: context.layout.yPosition(for: value.middle, viewPort: context.viewPort)
            )
            let lowerPoint = CGPoint(
                x: x,
                y: context.layout.yPosition(for: value.lower, viewPort: context.viewPort)
            )

            if connected {
                upperPath.addLine(to: upperPoint)
                middlePath.addLine(to: middlePoint)
                lowerPath.addLine(to: lowerPoint)
            } else {
                upperPath.move(to: upperPoint)
                middlePath.move(to: middlePoint)
                lowerPath.move(to: lowerPoint)
                upperPoints.removeAll(keepingCapacity: true)
                lowerPoints.removeAll(keepingCapacity: true)
            }
            upperPoints.append(upperPoint)
            lowerPoints.append(lowerPoint)
            connected = true
        }
        flushAreaSegment(upper: &upperPoints, lower: &lowerPoints, into: areaPath)

        upperLayer.path = upperPath
        middleLayer.path = middlePath
        lowerLayer.path = lowerPath
        areaLayer.path = areaPath
    }

    /// Formats the selected or latest visible channel value for the main-panel legend.
    ///
    /// - Parameter context: The coherent candle and indicator snapshot for this drawing pass.
    /// - Returns: Styled middle, upper, and lower values, or nil when the current index has no channel.
    func legend(context: Context) -> NSAttributedString? {
        guard let values = context.values(for: key, as: BandIndicatorValue.self),
              values.indices.contains(context.currentIndex),
              let value = values[context.currentIndex] else { return nil }

        let style = context.appearance.indicatorStyle(for: key, type: LineStyle.self)
        let color = style?.strokeColor ?? .label
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: context.appearance.legendFont
        ]
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(
            string: "\(key.name):\(formatted(value.middle)) ",
            attributes: attributes
        ))
        result.append(NSAttributedString(
            string: "UB:\(formatted(value.upper)) ",
            attributes: attributes
        ))
        result.append(NSAttributedString(
            string: "LB:\(formatted(value.lower)) ",
            attributes: attributes
        ))
        return result
    }

    /// Combines all three visible channel prices into the group's required value range.
    ///
    /// - Parameter context: The coherent candle and indicator snapshot for this drawing pass.
    /// - Returns: The merged visible bounds, or empty bounds when no channel values are available.
    func dataBounds(context: Context) -> ValueBounds {
        guard let visibleValues = context.visibleValues(for: key, as: BandIndicatorValue.self) else {
            return .empty
        }

        var result = ValueBounds.empty
        for value in visibleValues {
            guard let value else { continue }
            result.merge(other: ValueBounds(min: value.min, max: value.max))
        }
        return result
    }

    /// Appends one contiguous filled area segment and clears its point buffers.
    ///
    /// A segment needs at least two points on both edges; isolated values still appear on the line paths but
    /// do not produce a degenerate fill polygon.
    ///
    /// - Parameters:
    ///   - upper: Upper edge points for the current contiguous segment.
    ///   - lower: Lower edge points for the current contiguous segment.
    ///   - path: The destination area path.
    private func flushAreaSegment(upper: inout [CGPoint], lower: inout [CGPoint], into path: CGMutablePath) {
        defer {
            upper.removeAll(keepingCapacity: true)
            lower.removeAll(keepingCapacity: true)
        }
        guard upper.count > 1, upper.count == lower.count else { return }

        path.move(to: upper[0])
        for point in upper.dropFirst() { path.addLine(to: point) }
        for point in lower.reversed() { path.addLine(to: point) }
        path.closeSubpath()
    }

    /// Clears every path so removed or type-mismatched series do not leave stale drawing content.
    private func clearPaths() {
        upperLayer.path = nil
        middleLayer.path = nil
        lowerLayer.path = nil
        areaLayer.path = nil
    }

    /// Formats a channel price using the same price formatter as other main-panel renderers.
    ///
    /// - Parameter value: A finite channel price.
    /// - Returns: The localized or source-compatible price string.
    private func formatted(_ value: Double) -> String {
        priceFormatter.format(NSDecimalNumber(floatLiteral: value))
    }
}
