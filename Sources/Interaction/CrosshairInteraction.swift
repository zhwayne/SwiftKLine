//
//  CrosshairInteraction.swift
//  KLine
//
//  Created by W Zh on 2025/7/28.
//

import UIKit

@MainActor
protocol CrosshairInteractionDelegate: NSObjectProtocol {
    
    func updateCrosshair(location: CGPoint, itemIndex: Int)
}

class CrosshairInteraction: NSObject, UIInteraction, UIGestureRecognizerDelegate {
    
    weak var delegate: CrosshairInteractionDelegate?
    weak var view: UIView?
    private let layout: Layout
    private var location: CGPoint = .zero
    private var styleManager: StyleManager { .shared }
    
    init(layout: Layout, delegate: CrosshairInteractionDelegate) {
        self.delegate = delegate
        self.layout = layout
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
        guard let index = layout.indexInViewPort(on: location.x),
              let view else {
            return
        }
        CATransaction.begin()
        CATransaction.setDisableActions(false)
        CATransaction.setAnimationDuration(0)
        defer {
            CATransaction.commit()
        }
        
       
        let candleHalfWidth = styleManager.candleStyle.width * 0.5
        let indexInViewPort = index - layout.visibleRange.lowerBound
        location.x = layout.minX(at: indexInViewPort) + candleHalfWidth
        location.y = min(max(0, location.y), view.bounds.height - 1)
        delegate?.updateCrosshair(location: location, itemIndex: index)
    }
}
