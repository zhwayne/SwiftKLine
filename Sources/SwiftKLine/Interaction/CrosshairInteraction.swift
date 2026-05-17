//
//  CrosshairInteraction.swift
//  SwiftKLine
//
//  Created by zhwayne on 2025/7/28.
//

import UIKit

class CrosshairInteraction: NSObject, UIInteraction, UIGestureRecognizerDelegate {
    
    weak var view: UIView?
    private let layout: ChartLayout
    private let onCrosshairUpdate: (CGPoint, Int) -> Void
    private var location: CGPoint = .zero
    
    init(layout: ChartLayout, onCrosshairUpdate: @escaping (CGPoint, Int) -> Void) {
        self.layout = layout
        self.onCrosshairUpdate = onCrosshairUpdate
    }
    
    func willMove(to view: UIView?) { }
    
    func didMove(to view: UIView?) {
        self.view = view
        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(Self.handleTap(_:))
        )
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view?.addGestureRecognizer(tap)
        
        let longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(Self.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.25
        longPress.allowableMovement = 2
        longPress.cancelsTouchesInView = false
        longPress.delegate = self
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
    
    private func drawCrosshair() {
        guard let view else {
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
