//
//  PinchInteraction.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2025/07/27.
//

import SwiftKLineCore
import UIKit

/// The candle body width and gap produced by a pinch gesture.
struct CandleScaleChange {
    let width: CGFloat
    let gap: CGFloat
}

/// Applies cumulative gesture scale to the initial dimensions, preserving one logical candle anchor.
final class PinchInteraction: NSObject, UIInteraction {
    weak var view: UIView?
    private let layout: ChartLayout
    private let onScaleChange: (CandleScaleChange) -> Void
    private var initialDimensions: CandleDimensions?
    private var pinchCenterX: CGFloat = 0
    private var anchor: CGFloat = 0
    private var scrollingWasEnabled: Bool?
    private var scrollView: ChartScrollView { layout.scrollView }
    private lazy var recognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))

    init(layout: ChartLayout, onScaleChange: @escaping (CandleScaleChange) -> Void) {
        self.layout = layout
        self.onScaleChange = onScaleChange
    }

    func willMove(to view: UIView?) {
        finishPinch()
        self.view?.removeGestureRecognizer(recognizer)
    }

    func didMove(to view: UIView?) {
        self.view = view
        view?.addGestureRecognizer(recognizer)
    }

    @objc private func handlePinch(_ pinch: UIPinchGestureRecognizer) {
        switch pinch.state {
        case .began:
            finishPinch()
            guard pinch.numberOfTouches >= 2 else { return }
            let dimensions = layout.candleDimensions
            guard dimensions.width.isFinite, dimensions.width > 0, dimensions.gap.isFinite,
                  dimensions.gap >= 0, dimensions.itemWidth.isFinite else { return }
            let p1 = pinch.location(ofTouch: 0, in: scrollView.contentView)
            let p2 = pinch.location(ofTouch: 1, in: scrollView.contentView)
            let center = p1.x / 2 + p2.x / 2
            let logicalAnchor = (scrollView.contentOffset.x + center) / dimensions.itemWidth
            guard center.isFinite, logicalAnchor.isFinite else { return }
            initialDimensions = dimensions
            pinchCenterX = center
            anchor = logicalAnchor
            scrollingWasEnabled = scrollView.isScrollEnabled
            scrollView.isScrollEnabled = false
        case .changed:
            break
        default:
            finishPinch()
            return
        }
        guard let initialDimensions, pinch.scale.isFinite, pinch.scale > 0 else { return }
        let width = min(max(initialDimensions.width * pinch.scale, 2), 24)
        let ratio = width / initialDimensions.width
        guard ratio.isFinite else { return }
        let gap = initialDimensions.gap * ratio
        let stride = width + gap
        let desiredOffset = anchor * stride - pinchCenterX
        guard gap.isFinite, stride.isFinite, desiredOffset.isFinite else { return }
        onScaleChange(CandleScaleChange(width: width, gap: gap))
        // A host may remove the interaction while processing the dimension change.
        guard self.initialDimensions != nil else { return }
        scrollView.contentSize = layout.contentSize
        let minOffset = -scrollView.contentInset.left
        let maxOffset = max(minOffset, scrollView.contentSize.width - scrollView.bounds.width + scrollView.contentInset.right)
        let offset = min(max(desiredOffset, minOffset), maxOffset)
        if scrollView.contentOffset.x == offset {
            scrollView.delegate?.scrollViewDidScroll?(scrollView)
        } else { scrollView.contentOffset.x = offset }
        scrollView.setNeedsLayout()
    }

    private func finishPinch() {
        if let scrollingWasEnabled { scrollView.isScrollEnabled = scrollingWasEnabled }
        scrollingWasEnabled = nil
        initialDimensions = nil
    }
}
