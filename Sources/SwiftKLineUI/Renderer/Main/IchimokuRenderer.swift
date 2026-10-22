//
//  IchimokuRenderer.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/10/22.
//

import SwiftKLineCore
import UIKit

/// Draws one keyed Ichimoku Kinko Hyo output as five lines plus the Senkou A/B cloud.
///
/// The renderer reads ``IchimokuIndicatorValue`` outputs, resolves one color per line and two cloud colors,
/// and closes every path at nil values. Cloud quads are appended to a bullish or bearish fill layer according
/// to the relative order of Senkou Span A and Span B at the earlier point, so mixed trends remain visible in
/// one continuous overlay.
final class IchimokuRenderer: ChartRenderer {
    /// One cloud edge sample used to build filled quads between adjacent candles.
    private struct CloudPoint {
        let x: CGFloat
        let spanA: Double
        let spanB: Double
    }

    private let priceFormatter = PriceFormatter()

    private let tenkanLayer = CAShapeLayer()
    private let kijunLayer = CAShapeLayer()
    private let spanALayer = CAShapeLayer()
    private let spanBLayer = CAShapeLayer()
    private let chikouLayer = CAShapeLayer()
    private let bullishCloudLayer = CAShapeLayer()
    private let bearishCloudLayer = CAShapeLayer()

    /// The exact output identity; changing a calculation parameter installs a different renderer.
    var id: some Hashable { key }
    /// The Ichimoku series identity, including every period and the displacement.
    let key: SeriesKey

    /// Creates a renderer for one Ichimoku key and configures reusable layer defaults.
    ///
    /// - Parameter key: The exact series identity produced by the registered calculator.
    init(key: SeriesKey) {
        self.key = key
        for layer in [tenkanLayer, kijunLayer, spanALayer, spanBLayer, chikouLayer] {
            layer.lineWidth = 1
            layer.fillColor = UIColor.clear.cgColor
        }
        for layer in [bullishCloudLayer, bearishCloudLayer] {
            layer.strokeColor = UIColor.clear.cgColor
        }
    }

    /// Attaches the reusable cloud and line layers to the viewport canvas.
    ///
    /// Clouds are installed first so every line remains legible above the fill.
    ///
    /// - Parameter layer: The canvas layer owned by the current renderer group.
    func install(to layer: CALayer) {
        layer.addSublayer(bullishCloudLayer)
        layer.addSublayer(bearishCloudLayer)
        layer.addSublayer(tenkanLayer)
        layer.addSublayer(kijunLayer)
        layer.addSublayer(spanALayer)
        layer.addSublayer(spanBLayer)
        layer.addSublayer(chikouLayer)
    }

    /// Detaches every layer owned by this renderer.
    ///
    /// - Parameter layer: The canvas layer passed to ``install(to:)``.
    func uninstall(from layer: CALayer) {
        for layer in [bullishCloudLayer, bearishCloudLayer, tenkanLayer,
                      kijunLayer, spanALayer, spanBLayer, chikouLayer] {
            layer.removeFromSuperlayer()
        }
    }

    /// Rebuilds visible line and cloud paths and applies the current Ichimoku colors.
    ///
    /// Only the visible slice is traversed. Each line keeps its own connection state, and the cloud is
    /// rebuilt as independent quads between adjacent candles. A nil line or an incomplete span pair breaks
    /// the corresponding path so a data gap never produces a misleading line or filled area.
    ///
    /// - Parameters:
    ///   - layer: The canvas layer receiving the current frame.
    ///   - context: The coherent candle and indicator snapshot for this drawing pass.
    func draw(in layer: CALayer, context: Context) {
        guard let visibleValues = context.visibleValues(for: key, as: IchimokuIndicatorValue.self) else {
            clearPaths()
            return
        }

        let style = context.appearance.indicatorStyle(for: key, type: IchimokuStyle.self)
        tenkanLayer.strokeColor = (style?.tenkanColor ?? .label).cgColor
        kijunLayer.strokeColor = (style?.kijunColor ?? .label).cgColor
        spanALayer.strokeColor = (style?.spanAColor ?? .label).cgColor
        spanBLayer.strokeColor = (style?.spanBColor ?? .label).cgColor
        chikouLayer.strokeColor = (style?.chikouColor ?? .label).cgColor
        bullishCloudLayer.fillColor = (style?.bullishCloudColor
            ?? UIColor.systemGreen.withAlphaComponent(0.12)).cgColor
        bearishCloudLayer.fillColor = (style?.bearishCloudColor
            ?? UIColor.systemRed.withAlphaComponent(0.12)).cgColor

        let itemWidth = context.candleDimensions.itemWidth
        let candleHalfWidth = context.candleDimensions.width * 0.5
        let visibleMinX = CGFloat(context.visibleRange.lowerBound) * itemWidth
            - context.layout.scrollView.contentOffset.x

        let tenkanPath = CGMutablePath()
        let kijunPath = CGMutablePath()
        let spanAPath = CGMutablePath()
        let spanBPath = CGMutablePath()
        let chikouPath = CGMutablePath()
        let bullishCloudPath = CGMutablePath()
        let bearishCloudPath = CGMutablePath()

        var tenkanConnected = false
        var kijunConnected = false
        var spanAConnected = false
        var spanBConnected = false
        var chikouConnected = false
        var cloudPoints: [CloudPoint] = []

        for (offset, element) in visibleValues.enumerated() {
            let x = CGFloat(offset) * itemWidth + visibleMinX + candleHalfWidth
            let value = element

            append(value?.tenkan, at: x, to: tenkanPath, connected: &tenkanConnected, context: context)
            append(value?.kijun, at: x, to: kijunPath, connected: &kijunConnected, context: context)
            append(value?.spanA, at: x, to: spanAPath, connected: &spanAConnected, context: context)
            append(value?.spanB, at: x, to: spanBPath, connected: &spanBConnected, context: context)
            append(value?.chikou, at: x, to: chikouPath, connected: &chikouConnected, context: context)

            if let value, let spanA = value.spanA, let spanB = value.spanB,
               spanA.isFinite, spanB.isFinite {
                cloudPoints.append(CloudPoint(x: x, spanA: spanA, spanB: spanB))
            } else {
                appendCloud(
                    cloudPoints,
                    into: bullishCloudPath,
                    bearish: bearishCloudPath,
                    context: context
                )
                cloudPoints.removeAll(keepingCapacity: true)
            }
        }
        appendCloud(
            cloudPoints,
            into: bullishCloudPath,
            bearish: bearishCloudPath,
            context: context
        )

        tenkanLayer.path = tenkanPath
        kijunLayer.path = kijunPath
        spanALayer.path = spanAPath
        spanBLayer.path = spanBPath
        chikouLayer.path = chikouPath
        bullishCloudLayer.path = bullishCloudPath
        bearishCloudLayer.path = bearishCloudPath
    }

    /// Formats every available line at the selected or latest visible index for the main-panel legend.
    ///
    /// - Parameter context: The coherent candle and indicator snapshot for this drawing pass.
    /// - Returns: Styled Tenkan, Kijun, Span A, Span B, and Chikou values, or nil when none are available.
    func legend(context: Context) -> NSAttributedString? {
        guard let values = context.values(for: key, as: IchimokuIndicatorValue.self),
              values.indices.contains(context.currentIndex),
              let value = values[context.currentIndex],
              value.min != nil else { return nil }

        let style = context.appearance.indicatorStyle(for: key, type: IchimokuStyle.self)
        let font = context.appearance.legendFont
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(
            string: "\(key.name): ",
            attributes: [.foregroundColor: UIColor.label, .font: font]
        ))

        /// Appends one compact, line-colored value when it is present and finite.
        func append(_ title: String, value: Double?, color: UIColor) {
            guard let value, value.isFinite else { return }
            result.append(NSAttributedString(
                string: "\(title):\(priceFormatter.format(value as NSNumber)) ",
                attributes: [.foregroundColor: color, .font: font]
            ))
        }

        append("T", value: value.tenkan, color: style?.tenkanColor ?? .label)
        append("K", value: value.kijun, color: style?.kijunColor ?? .label)
        append("A", value: value.spanA, color: style?.spanAColor ?? .label)
        append("B", value: value.spanB, color: style?.spanBColor ?? .label)
        append("C", value: value.chikou, color: style?.chikouColor ?? .label)
        return result
    }

    /// Combines all available visible line and cloud prices into the group’s required value range.
    ///
    /// - Parameter context: The coherent candle and indicator snapshot for this drawing pass.
    /// - Returns: The merged visible bounds, or empty bounds when no values are available.
    func dataBounds(context: Context) -> ValueBounds {
        guard let visibleValues = context.visibleValues(for: key, as: IchimokuIndicatorValue.self) else {
            return .empty
        }

        var result = ValueBounds.empty
        for value in visibleValues {
            guard let value, let min = value.min, let max = value.max else { continue }
            result.merge(other: ValueBounds(min: min, max: max))
        }
        return result
    }

    /// Extends one line with a finite value, resetting its connection at a gap.
    ///
    /// - Parameters:
    ///   - value: The optional line price.
    ///   - x: The viewport x coordinate of the candle.
    ///   - path: The destination line path.
    ///   - connected: Whether the previous finite value can be joined to this one.
    ///   - context: The drawing context providing the price-to-y mapping.
    private func append(
        _ value: Double?,
        at x: CGFloat,
        to path: CGMutablePath,
        connected: inout Bool,
        context: Context
    ) {
        guard let value, value.isFinite else {
            connected = false
            return
        }
        let point = CGPoint(
            x: x,
            y: context.layout.yPosition(for: value, viewPort: context.viewPort)
        )
        if connected {
            path.addLine(to: point)
        } else {
            path.move(to: point)
            connected = true
        }
    }

    /// Appends one filled cloud quad per adjacent sample pair to the appropriate color path.
    ///
    /// The quad is colored by the relative order of the two spans at its left edge. A single isolated sample
    /// produces no fill because a cloud needs two adjacent edges.
    ///
    /// - Parameters:
    ///   - points: Contiguous valid cloud samples in visible order.
    ///   - bullish: The destination path for Senkou Span A at or above Span B.
    ///   - bearish: The destination path for Senkou Span A below Span B.
    ///   - context: The drawing context providing the price-to-y mapping.
    private func appendCloud(
        _ points: [CloudPoint],
        into bullish: CGMutablePath,
        bearish: CGMutablePath,
        context: Context
    ) {
        guard points.count > 1 else { return }
        for index in 1..<points.count {
            let left = points[index - 1]
            let right = points[index]
            let path = left.spanA >= left.spanB ? bullish : bearish
            path.move(to: CGPoint(x: left.x, y: yPosition(left.spanA, context: context)))
            path.addLine(to: CGPoint(x: right.x, y: yPosition(right.spanA, context: context)))
            path.addLine(to: CGPoint(x: right.x, y: yPosition(right.spanB, context: context)))
            path.addLine(to: CGPoint(x: left.x, y: yPosition(left.spanB, context: context)))
            path.closeSubpath()
        }
    }

    /// Converts one price to its viewport y coordinate.
    ///
    /// - Parameters:
    ///   - value: A finite price.
    ///   - context: The drawing context providing the current value bounds.
    /// - Returns: The y coordinate used by cloud quads.
    private func yPosition(_ value: Double, context: Context) -> CGFloat {
        context.layout.yPosition(for: value, viewPort: context.viewPort)
    }

    /// Clears every path so removed or type-mismatched series do not leave stale drawing content.
    private func clearPaths() {
        tenkanLayer.path = nil
        kijunLayer.path = nil
        spanALayer.path = nil
        spanBLayer.path = nil
        chikouLayer.path = nil
        bullishCloudLayer.path = nil
        bearishCloudLayer.path = nil
    }
}
