//
//  PinchInteraction.swift
//  SwiftKLine
//
//  Created by W Zh on 2025/7/27.
//

import UIKit

class PinchInteraction: NSObject, UIInteraction {
    
    weak var view: UIView?
    
    // pinch
    private var pinchCenterX: CGFloat = 0
    private var oldScale: CGFloat = 1
    private let klineConfig: KLineConfiguration
    private var scrollView: ChartScrollView? { layout.scrollView as? ChartScrollView }
    private let layout: KLineLayout
    
    init(layout: KLineLayout, configuration: KLineConfiguration) {
        self.layout = layout
        self.klineConfig = configuration
    }

    func willMove(to view: UIView?) {
        
    }

    func didMove(to view: UIView?) {
        // pinch
        let pinch = UIPinchGestureRecognizer(
            target: self,
            action: #selector(Self.handlePinch(_:))
        )
        view?.addGestureRecognizer(pinch)
    }
    
    @objc private func handlePinch(_ pinch: UIPinchGestureRecognizer) {
        guard let scrollView else { return }
        switch pinch.state {
        case .began:
            scrollView.isScrollEnabled = false
            let p1 = pinch.location(ofTouch: 0, in: scrollView.contentView)
            let p2 = pinch.location(ofTouch: 1, in: scrollView.contentView)
            pinchCenterX = (p1.x + p2.x) / 2
            oldScale = 1.0
        case .changed:
            break;
            
        default:
            scrollView.isScrollEnabled = true
        }
        
        let difValue = pinch.scale - oldScale
        let candleStyle = klineConfig.candleStyle
        let newLineWidth = candleStyle.width * (difValue + 1)
        let newGap = candleStyle.gap * (difValue + 1)
        guard (2...24).contains(newLineWidth) else { return }
        
        klineConfig.candleStyle.width = newLineWidth
        klineConfig.candleStyle.gap = newGap
        oldScale = pinch.scale
        
        // 更新 contentSize
        let contentOffsetAtPinch = scrollView.contentOffset.x + pinchCenterX
        let oldContentSize = scrollView.contentSize
        scrollView.contentSize = layout.contentSize
        
        
        // 算新的内容偏移量
        let scale = scrollView.contentSize.width / oldContentSize.width
        let newContentOffsetAtPinch = contentOffsetAtPinch * scale
        var newContentOffsetX = newContentOffsetAtPinch - pinchCenterX
        
        // 限制偏移量的范围
        newContentOffsetX = max(-scrollView.contentInset.left, newContentOffsetX)
        let maxContentOffsetX = scrollView.contentSize.width - scrollView.bounds.width + scrollView.contentInset.right
        newContentOffsetX = min(maxContentOffsetX, newContentOffsetX)

        // 更新 contentOffset 并重绘内容
        if scrollView.contentOffset.x == newContentOffsetX {
            scrollView.setNeedsLayout()
            scrollView.layoutIfNeeded()
            scrollView.delegate?.scrollViewDidScroll?(scrollView)
        } else {
            scrollView.contentOffset.x = newContentOffsetX
        }
    }
}
