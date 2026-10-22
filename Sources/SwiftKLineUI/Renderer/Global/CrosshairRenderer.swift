//
//  CrosshairRenderer.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2025/03/28.
//

import SwiftKLineCore
import UIKit

/// Draws crosshair guides, candle details, and selected time/value labels using geometry prepared by the crosshair coordinator.
final class CrosshairRenderer: ChartRenderer {
    
    var id: some Hashable { ObjectIdentifier(CrosshairRenderer.self) }
    
    private let feedback = UISelectionFeedbackGenerator()
    private let dateFormatter: DateFormatter
    private let yValueFormatter: NumberFormatter
    private var lastLocation: CGPoint = .zero
    private let dashLineLayer = CAShapeLayer()
    private let pointLayer = CAShapeLayer()
    private let klineMarkView: MarkView
    private let dateLabel = PaddedLabel()
    private let yAxisValueLabel = PaddedLabel()
    
    var selectedGroup: RendererGroup?
    var candleGroup: RendererGroup?
    var timelineGroup: RendererGroup?
        
    init(configuration: ChartAppearance) {
        klineMarkView = MarkView(configuration: configuration)
        dashLineLayer.lineWidth = 1 / UIScreen.main.scale
        dashLineLayer.lineDashPattern = [2, 2]
        dashLineLayer.strokeColor = UIColor.label.cgColor
        dashLineLayer.zPosition = 1
        pointLayer.fillColor = UIColor.label.cgColor
        
        dateLabel.edgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        dateLabel.backgroundColor = .label
        dateLabel.textColor = .systemBackground
        dateLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        dateLabel.textAlignment = .center
        dateLabel.layer.masksToBounds = true
        dateLabel.layer.cornerRadius = 3
        
        yAxisValueLabel.edgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        yAxisValueLabel.backgroundColor = .label
        yAxisValueLabel.textColor = .systemBackground
        yAxisValueLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        yAxisValueLabel.textAlignment = .center
        yAxisValueLabel.layer.masksToBounds = true
        yAxisValueLabel.layer.cornerRadius = 3
        
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
        
        yValueFormatter = NumberFormatter()
        yValueFormatter.minimumFractionDigits = 2
        yValueFormatter.maximumFractionDigits = 2
        yValueFormatter.numberStyle = .decimal
    }
    
    func install(to layer: CALayer) {
        layer.addSublayer(dashLineLayer)
        layer.addSublayer(pointLayer)
        layer.owningView?.addSubview(klineMarkView)
        layer.owningView?.addSubview(dateLabel)
        layer.owningView?.addSubview(yAxisValueLabel)
    }
    
    func uninstall(from layer: CALayer) {
        dashLineLayer.removeFromSuperlayer()
        pointLayer.removeFromSuperlayer()
        klineMarkView.removeFromSuperview()
        dateLabel.removeFromSuperview()
        yAxisValueLabel.removeFromSuperview()
    }
    
    func draw(in layer: CALayer, context: Context) {
        guard let location = context.location,
              let selectedGroup,
              let candleGroup,
              let timelineGroup else {
            return
        }
        defer { lastLocation = location }
        if lastLocation.x != location.x {
            feedback.selectionChanged()
        }
        // MARK: - Vertical crosshair line
        let path = CGMutablePath()
        path.move(to: CGPoint(x: location.x, y: 0))
        path.addLine(to: CGPoint(x: location.x, y: layer.bounds.maxY))
        
        // MARK: - Horizontal crosshair line
        if selectedGroup.chartSection != .timeline/*, group.viewPort.contains(location)*/ {
            path.move(to: CGPoint(x: 0, y: location.y))
            path.addLine(to: CGPoint(x: layer.bounds.width, y: location.y))
        }
        dashLineLayer.path = path
        
        // MARK: - Crosshair marker
        let pointRect = CGRect(x: location.x - 2, y: location.y - 2, width: 4, height: 4)
        pointLayer.path = CGPath(ellipseIn: pointRect, transform: nil)
        
        if let index = context.layout.indexInViewport(on: location.x) {
            let item = context.items[index]
            
            // MARK: - Candle details
            klineMarkView.item = item
            let rightSide = location.x < context.groupFrame.midX - 16
            let markSize = klineMarkView.systemLayoutSizeFitting(candleGroup.groupFrame.size)
            let markX = rightSide ? candleGroup.groupFrame.width - 88 - markSize.width : 12
            let markY: CGFloat = candleGroup.viewPort.minY - candleGroup.padding.top * 0.5
            klineMarkView.frame = CGRect(
                x: markX,
                y: markY,
                width: markSize.width,
                height: markSize.height
            )
            
            // MARK: - Selected candle time
            let date = Date(timeIntervalSince1970: TimeInterval(item.timestamp))
            let timeString = dateFormatter.string(from: date)
            dateLabel.text = timeString
            let dateSize = dateLabel.systemLayoutSizeFitting(timelineGroup.groupFrame.size)
            let dateX = location.x - dateSize.width * 0.5
            let dateY = timelineGroup.groupFrame.minY
            let dateRect = CGRect(
                x: max(0, min(dateX, timelineGroup.groupFrame.width - dateSize.width)),
                y: dateY,
                width: dateSize.width,
                height: timelineGroup.groupFrame.height
            )
            dateLabel.frame = dateRect
        }
        
        // MARK: - Selected group value
        if selectedGroup.chartSection != .timeline {
            let yValue = context.layout.value(on: location.y, viewPort: selectedGroup.viewPort)
            yAxisValueLabel.text = yValueFormatter.string(from: NSDecimalNumber(floatLiteral: yValue))
            let yAxisValueSize = yAxisValueLabel.systemLayoutSizeFitting(selectedGroup.groupFrame.size)
            yAxisValueLabel.frame = CGRect(
                x: selectedGroup.groupFrame.width - yAxisValueSize.width - 12,
                y: location.y - yAxisValueSize.height * 0.5,
                width: yAxisValueSize.width,
                height: yAxisValueSize.height
            )
        } else {
            yAxisValueLabel.text = nil
            yAxisValueLabel.frame = .zero
        }
    }
}
