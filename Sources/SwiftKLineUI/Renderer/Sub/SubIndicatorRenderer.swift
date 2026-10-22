import SwiftKLineCore
import UIKit

/// Shared, visible-slice-only drawing for scalar and compound lower-panel outputs.
/// Each configured key owns its paths; the first renderer in a panel owns the combined legend.
final class SubIndicatorRenderer: ChartRenderer, LegendUpdatable {
    let key: SeriesKey
    var id: some Hashable { key }
    private let names: [String]
    private let read: (ChartContext, Range<Int>) -> [[Double?]]?
    private let lines: [CAShapeLayer]
    private let references: [Double]
    private let anchors: [Double]
    private let fillRange: ClosedRange<Double>?
    private let referenceLayer = CAShapeLayer()
    private let fillLayer = CAShapeLayer()
    private let legendLayer = CATextLayer()
    private let showsLegend: Bool
    private let formatter = PriceFormatter()
    private let volumeFormatter = VolumeFormatter()

    private init<Value>(
        key: SeriesKey, names: [String], type: Value.Type,
        components: [KeyPath<Value, Double?>], references: [Double], anchors: [Double],
        fillRange: ClosedRange<Double>?, showsLegend: Bool
    ) {
        self.key = key
        self.names = names
        self.references = references
        self.anchors = anchors
        self.fillRange = fillRange
        self.showsLegend = showsLegend
        read = { context, range in
            guard let values = context.values(for: key, as: type),
                  range.lowerBound >= 0, range.upperBound <= values.count else { return nil }
            return components.map { component in
                range.map { index in values[index]?[keyPath: component].flatMap { $0.isFinite ? $0 : nil } }
            }
        }
        lines = names.map { _ in
            let layer = CAShapeLayer()
            layer.fillColor = nil
            layer.lineWidth = 1
            return layer
        }
        referenceLayer.fillColor = nil
        referenceLayer.lineWidth = 1
        referenceLayer.lineDashPattern = [3, 3]
        fillLayer.strokeColor = nil
        legendLayer.alignmentMode = .left
        legendLayer.isWrapped = true
    }

    /// Complete keys select the typed store and participate in renderer reconciliation.
    static func make(key: SeriesKey, showsLegend: Bool = true) -> SubIndicatorRenderer {
        if key.indicatorID == .kdj {
            return SubIndicatorRenderer(key: key, names: ["K", "D", "J"], type: KDJIndicatorValue.self,
                components: [\.optionalK, \.optionalD, \.optionalJ], references: [20, 80], anchors: [0, 100],
                fillRange: 20...80, showsLegend: showsLegend)
        }
        if key.indicatorID == .dmi {
            return SubIndicatorRenderer(key: key, names: ["+DI", "−DI", "ADX"], type: DMIIndicatorValue.self,
                components: [\.optionalPlusDI, \.optionalMinusDI, \.adx], references: [20, 25], anchors: [0, 100],
                fillRange: nil, showsLegend: showsLegend)
        }
        let references: [Double]
        let anchors: [Double]
        let fill: ClosedRange<Double>?
        switch key.indicatorID {
        case .wr: references = [-80, -20]; anchors = [-100, 0]; fill = -80 ... -20
        case .mfi: references = [20, 80]; anchors = [0, 100]; fill = 20...80
        case .cci: references = [-100, 0, 100]; anchors = [-100, 100]; fill = -100...100
        case .roc, .trix: references = [0]; anchors = [0]; fill = nil
        case .atr: references = []; anchors = [0]; fill = nil
        default: references = []; anchors = []; fill = nil
        }
        return SubIndicatorRenderer(key: key, names: [key.name], type: Double.self,
            components: [\.optionalValue], references: references, anchors: anchors,
            fillRange: fill, showsLegend: showsLegend)
    }

    func install(to layer: CALayer) {
        layer.addSublayer(fillLayer)
        layer.addSublayer(referenceLayer)
        lines.forEach { layer.addSublayer($0) }
        if showsLegend {
            layer.addSublayer(legendLayer)
            updateLegendScale()
        }
    }

    func uninstall(from layer: CALayer) {
        ([fillLayer, referenceLayer, legendLayer] + lines).forEach { $0.removeFromSuperlayer() }
    }

    private func colors(context: Context) -> [UIColor] {
        if key.indicatorID == .kdj {
            let style = context.appearance.indicatorStyle(for: key, type: KDJStyle.self) ?? KDJStyle()
            return [style.kColor, style.dColor, style.jColor]
        }
        if key.indicatorID == .dmi {
            let style = context.appearance.indicatorStyle(for: key, type: DMIStyle.self) ?? DMIStyle()
            return [style.plusDIColor, style.minusDIColor, style.adxColor]
        }
        return [context.appearance.indicatorStyle(for: key, type: LineStyle.self)?.strokeColor ?? .label]
    }

    func draw(in layer: CALayer, context: Context) {
        updateLegend(context: context)
        guard !context.visibleRange.isEmpty, let samples = read(context, context.visibleRange) else {
            lines.forEach { $0.path = nil }
            referenceLayer.path = nil
            fillLayer.path = nil
            return
        }
        let colors = colors(context: context)
        let width = context.candleDimensions.itemWidth
        let origin = CGFloat(context.visibleRange.lowerBound) * width
            - context.layout.scrollView.contentOffset.x + context.candleWidth / 2
        for (index, samples) in samples.enumerated() {
            let path = CGMutablePath()
            var connected = false
            for (offset, sample) in samples.enumerated() {
                guard let sample else { connected = false; continue }
                let point = CGPoint(x: origin + CGFloat(offset) * width,
                    y: context.layout.yPosition(for: sample, viewPort: context.viewPort))
                if connected { path.addLine(to: point) } else { path.move(to: point) }
                connected = true
            }
            lines[index].strokeColor = colors[index].cgColor
            lines[index].path = path
        }
        let path = CGMutablePath()
        for value in references {
            let y = context.layout.yPosition(for: value, viewPort: context.viewPort)
            path.move(to: CGPoint(x: context.viewPort.minX, y: y))
            path.addLine(to: CGPoint(x: context.viewPort.maxX, y: y))
        }
        referenceLayer.strokeColor = UIColor.secondaryLabel.withAlphaComponent(0.45).cgColor
        referenceLayer.path = path
        if let range = fillRange {
            let top = context.layout.yPosition(for: range.upperBound, viewPort: context.viewPort)
            let bottom = context.layout.yPosition(for: range.lowerBound, viewPort: context.viewPort)
            fillLayer.path = CGPath(rect: CGRect(x: context.viewPort.minX, y: top,
                width: context.viewPort.width, height: max(0, bottom - top)), transform: nil)
            fillLayer.fillColor = colors[0].withAlphaComponent(0.05).cgColor
        } else { fillLayer.path = nil }
    }

    func dataBounds(context: Context) -> ValueBounds {
        var bounds = ValueBounds.empty
        for value in anchors { bounds.merge(other: ValueBounds(min: value, max: value)) }
        guard let samples = read(context, context.visibleRange) else { return bounds }
        for line in samples {
            for value in line {
                if let value { bounds.merge(other: ValueBounds(min: value, max: value)) }
            }
        }
        return bounds
    }

    func legend(context: Context) -> NSAttributedString? {
        let index = context.currentIndex
        guard index >= 0, index < context.items.count, let samples = read(context, index..<(index + 1)),
              samples.contains(where: { $0.first.flatMap { $0 } != nil }) else { return nil }
        let colors = colors(context: context)
        let parameters: String
        if key.indicatorID == .kdj {
            parameters = ["period", "kPeriod", "dPeriod"].compactMap { key.parameters[$0] }.joined(separator: ",")
        } else if key.indicatorID == .dmi {
            parameters = ["diPeriod", "adxPeriod"].compactMap { key.parameters[$0] }.joined(separator: ",")
        } else { parameters = key.parameters["period"] ?? "" }
        let title = key.name + (parameters.isEmpty ? "" : "(\(parameters))")
        let result = NSMutableAttributedString(string: title + " ", attributes: [
            .font: context.appearance.legendFont, .foregroundColor: UIColor.label
        ])
        for (i, values) in samples.enumerated() {
            guard let value = values[0] else { continue }
            let text = key.indicatorID == .obv
                ? (value < 0 ? "−" : "") + volumeFormatter.format(abs(value) as NSNumber)
                : formatter.format(value as NSNumber)
            result.append(NSAttributedString(string: "\(names[i]):\(text) ", attributes: [
                .font: context.appearance.legendFont, .foregroundColor: colors[i]
            ]))
        }
        return result
    }

    func updateLegend(context: Context) {
        guard showsLegend else { return }
        updateLegendScale()
        legendLayer.string = context.legendText
        legendLayer.frame = context.legendFrame
    }

    /// Standalone canvas layers default to 1x; text must use the nearest UIView's actual display scale.
    /// Recheck during legend refresh so attaching or moving the chart can update its text backing store.
    private func updateLegendScale() {
        guard let canvas = legendLayer.superlayer else { return }
        let view = canvas.owningView
        let scale = view?.window?.screen.scale ?? view?.contentScaleFactor ?? canvas.contentsScale
        if legendLayer.contentsScale != scale { legendLayer.contentsScale = scale }
    }
}

private extension KDJIndicatorValue {
    var optionalK: Double? { k }
    var optionalD: Double? { d }
    var optionalJ: Double? { j }
}
private extension DMIIndicatorValue {
    var optionalPlusDI: Double? { plusDI }
    var optionalMinusDI: Double? { minusDI }
}
private extension Double {
    var optionalValue: Double? { self }
}
