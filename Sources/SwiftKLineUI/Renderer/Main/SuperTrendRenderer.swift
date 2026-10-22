//
//  SuperTrendRenderer.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/10/22.
//

import SwiftKLineCore
import UIKit

/// Draws one keyed SuperTrend output as directional line and ribbon layers.
///
/// The renderer reads ``SuperTrendIndicatorValue`` outputs and colors each line segment by the trend state of
/// its later endpoint, so a flip stays visible without inspecting consecutive prices again. The translucent
/// ribbon shades the area between the active line and the candle close; it restarts at trend flips and data
/// gaps so the two sides of a flip are never joined into one filled region. Nil or non-finite values break
/// both line paths and the ribbon, and a missing series clears stale content.
final class SuperTrendRenderer: ChartRenderer {
    private let priceFormatter = PriceFormatter()

    private let upFillLayer = CAShapeLayer()
    private let downFillLayer = CAShapeLayer()
    private let upLayer = CAShapeLayer()
    private let downLayer = CAShapeLayer()

    /// The exact output identity; changing a calculation parameter installs a different renderer.
    var id: some Hashable { key }
    /// The SuperTrend series identity, including every calculation parameter.
    let key: SeriesKey

    /// Creates a renderer for one SuperTrend key and configures reusable layer defaults.
    ///
    /// - Parameter key: The exact series identity produced by the registered calculator.
    init(key: SeriesKey) {
        self.key = key
        for layer in [upFillLayer, downFillLayer] {
            layer.fillColor = UIColor.clear.cgColor
            layer.strokeColor = UIColor.clear.cgColor
            layer.lineWidth = 0
        }
        for layer in [upLayer, downLayer] {
            layer.lineWidth = 1
            layer.fillColor = UIColor.clear.cgColor
        }
    }

    /// Attaches the reusable ribbon and line layers to the viewport canvas.
    ///
    /// Ribbons are installed before the lines so the directional outlines stay crisp on top of their fills.
    ///
    /// - Parameter layer: The canvas layer owned by the current renderer group.
    func install(to layer: CALayer) {
        layer.addSublayer(upFillLayer)
        layer.addSublayer(downFillLayer)
        layer.addSublayer(upLayer)
        layer.addSublayer(downLayer)
    }

    /// Detaches every layer owned by this renderer.
    ///
    /// - Parameter layer: The canvas layer passed to ``install(to:)``.
    func uninstall(from layer: CALayer) {
        upFillLayer.removeFromSuperlayer()
        downFillLayer.removeFromSuperlayer()
        upLayer.removeFromSuperlayer()
        downLayer.removeFromSuperlayer()
    }

    /// Rebuilds visible line and ribbon paths, then applies the current directional colors.
    ///
    /// Only the visible slice is traversed. Line segments connect adjacent finite values while the trend
    /// direction is unchanged; a flip starts a new path in the opposite layer instead of drawing a long
    /// diagonal between the two bands, producing a one-bar hand-off. A ribbon is emitted only for a run of
    /// at least two bars in one direction; flips and data gaps start a new run so the filled areas never span
    /// opposite trends or missing candles.
    ///
    /// - Parameters:
    ///   - layer: The canvas layer receiving the current frame.
    ///   - context: The coherent candle and indicator snapshot for this drawing pass.
    func draw(in layer: CALayer, context: Context) {
        guard let visibleValues = context.visibleValues(for: key, as: SuperTrendIndicatorValue.self) else {
            clearPaths()
            return
        }

        let style = context.appearance.indicatorStyle(for: key, type: SuperTrendStyle.self)
        let upColor = style?.upColor ?? .systemBlue
        let downColor = style?.downColor ?? .systemOrange
        upLayer.strokeColor = upColor.cgColor
        downLayer.strokeColor = downColor.cgColor
        upFillLayer.fillColor = (style?.upFillColor ?? upColor.withAlphaComponent(0.08)).cgColor
        downFillLayer.fillColor = (style?.downFillColor ?? downColor.withAlphaComponent(0.08)).cgColor

        let itemWidth = context.candleDimensions.itemWidth
        let candleHalfWidth = context.candleDimensions.width * 0.5
        let visibleMinX = CGFloat(context.visibleRange.lowerBound) * itemWidth
            - context.layout.scrollView.contentOffset.x

        let upPath = CGMutablePath()
        let downPath = CGMutablePath()
        let upFillPath = CGMutablePath()
        let downFillPath = CGMutablePath()

        // A ribbon run keeps its own points because the close side of the polygon is traversed right-to-left.
        var activeRun: RibbonRun?
        var previousPoint: CGPoint?
        var previousIsUp: Bool?

        let visibleItems = context.visibleItems
        let canDrawRibbon = visibleItems.count == visibleValues.count
        let visibleStartIndex = visibleItems.startIndex

        for (offset, value) in visibleValues.enumerated() {
            guard let value, value.value.isFinite else {
                previousPoint = nil
                previousIsUp = nil
                if let activeRun {
                    self.finish(activeRun: activeRun, in: upFillPath, and: downFillPath)
                }
                activeRun = nil
                continue
            }

            let x = CGFloat(offset) * itemWidth + visibleMinX + candleHalfWidth
            let point = CGPoint(x: x, y: context.layout.yPosition(for: value.value, viewPort: context.viewPort))

            if let previousPoint, previousIsUp == value.isUp {
                let path = value.isUp ? upPath : downPath
                path.move(to: previousPoint)
                path.addLine(to: point)
            }
            previousPoint = point
            previousIsUp = value.isUp

            guard canDrawRibbon else { continue }
            let item = visibleItems[visibleStartIndex + offset]
            let pricePoint = CGPoint(
                x: x,
                y: context.layout.yPosition(for: item.close, viewPort: context.viewPort)
            )

            if activeRun?.isUp != value.isUp {
                if let activeRun {
                    self.finish(activeRun: activeRun, in: upFillPath, and: downFillPath)
                }
                activeRun = RibbonRun(isUp: value.isUp)
            }
            activeRun?.linePoints.append(point)
            activeRun?.pricePoints.append(pricePoint)
        }

        if let activeRun {
            self.finish(activeRun: activeRun, in: upFillPath, and: downFillPath)
        }

        upLayer.path = upPath
        downLayer.path = downPath
        upFillLayer.path = upFillPath
        downFillLayer.path = downFillPath
    }

    /// Formats the selected or latest visible SuperTrend value for the main-panel legend.
    ///
    /// - Parameter context: The coherent candle and indicator snapshot for this drawing pass.
    /// - Returns: A direction-colored value with an up/down marker, or nil when the current index has no value.
    func legend(context: Context) -> NSAttributedString? {
        guard let values = context.values(for: key, as: SuperTrendIndicatorValue.self),
              values.indices.contains(context.currentIndex),
              let value = values[context.currentIndex],
              value.value.isFinite else { return nil }

        let style = context.appearance.indicatorStyle(for: key, type: SuperTrendStyle.self)
        let color = value.isUp ? (style?.upColor ?? .systemBlue) : (style?.downColor ?? .systemOrange)
        let marker = value.isUp ? "▲" : "▼"
        return NSAttributedString(
            string: "\(key.name): \(priceFormatter.format(value.value as NSNumber)) \(marker) ",
            attributes: [.foregroundColor: color, .font: context.appearance.legendFont]
        )
    }

    /// Combines finite visible SuperTrend values into the group’s required value range.
    ///
    /// - Parameter context: The coherent candle and indicator snapshot for this drawing pass.
    /// - Returns: The merged visible bounds, or empty bounds when no values are available.
    func dataBounds(context: Context) -> ValueBounds {
        guard let visibleValues = context.visibleValues(for: key, as: SuperTrendIndicatorValue.self) else {
            return .empty
        }

        var result = ValueBounds.empty
        for value in visibleValues {
            guard let value, value.value.isFinite else { continue }
            result.merge(other: ValueBounds(min: value.value, max: value.value))
        }
        return result
    }

    /// Clears every path so removed or type-mismatched series do not leave stale drawing content.
    private func clearPaths() {
        upLayer.path = nil
        downLayer.path = nil
        upFillLayer.path = nil
        downFillLayer.path = nil
    }

    /// Appends one closed line-to-price ribbon to the matching directional fill path.
    ///
    /// - Parameters:
    ///   - run: A completed run of adjacent bars sharing one trend direction.
    ///   - upPath: The fill path used while the line supports price.
    ///   - downPath: The fill path used while the line caps price.
    private func finish(activeRun run: RibbonRun, in upPath: CGMutablePath, and downPath: CGMutablePath) {
        guard run.linePoints.count >= 2, run.linePoints.count == run.pricePoints.count else { return }
        let path = run.isUp ? upPath : downPath
        path.move(to: run.linePoints[0])
        for point in run.linePoints.dropFirst() {
            path.addLine(to: point)
        }
        for point in run.pricePoints.reversed() {
            path.addLine(to: point)
        }
        path.closeSubpath()
    }
}

/// One contiguous ribbon segment: the active SuperTrend points and the matching candle closes.
private struct RibbonRun {
    let isUp: Bool
    var linePoints: [CGPoint] = []
    var pricePoints: [CGPoint] = []
}
