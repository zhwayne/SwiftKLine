//
//  CrosshairInteraction.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2025/07/28.
//

import SwiftKLineCore
import UIKit

/// Maps taps and long presses into a clamped viewport location and absolute candle selection.
final class CrosshairInteraction: NSObject, UIInteraction, UIGestureRecognizerDelegate {
    
    weak var view: UIView?
    private let layout: ChartLayout
    private let onCrosshairUpdate: (CGPoint, Int) -> Void
    private var location: CGPoint = .zero
    
    init(layout: ChartLayout, onCrosshairUpdate: @escaping (CGPoint, Int) -> Void) {
        self.layout = layout
        self.onCrosshairUpdate = onCrosshairUpdate
    }
    
    private lazy var tap: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        return recognizer
    }()
    private lazy var longPress: UILongPressGestureRecognizer = {
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        recognizer.minimumPressDuration = 0.25
        recognizer.allowableMovement = 2
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        return recognizer
    }()

    func willMove(to view: UIView?) {
        self.view?.removeGestureRecognizer(tap)
        self.view?.removeGestureRecognizer(longPress)
    }

    func didMove(to view: UIView?) {
        self.view = view
        view?.addGestureRecognizer(tap)
        view?.addGestureRecognizer(longPress)
    }

    @objc private func handleTap(_ tap: UITapGestureRecognizer) {
        location = tap.location(in: tap.view)
        drawCrosshair()
    }
    
    @objc private func handleLongPress(_ longPress: UILongPressGestureRecognizer) {
        location = longPress.location(in: longPress.view)
        switch longPress.state {
        case .began, .changed: drawCrosshair()
        default: break
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIControl {
            return false
        }
        return true
    }
    
    /// Snaps x to the selected candle center, clamps y to the chart, and forwards the selection to ChartView.
    private func drawCrosshair() {
        guard let view, layout.itemCount > 0, view.bounds.height > 0,
              location.x.isFinite, location.y.isFinite else {
            return
        }
        
        let index = layout.indexInViewport(on: location.x) ?? layout.itemCount - 1
        let candleHalfWidth = layout.candleDimensions.width * 0.5
        let indexInViewport = index - layout.visibleRange.lowerBound
        location.x = layout.xPosition(at: indexInViewport) + candleHalfWidth
        location.y = min(max(0, location.y), view.bounds.height - 1)
        onCrosshairUpdate(location, index)
    }
}
