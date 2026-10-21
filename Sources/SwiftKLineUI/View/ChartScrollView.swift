//
//  ChartScrollView.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2025/03/22.
//

import SwiftKLineCore
import Foundation
import UIKit

/// Scrolls logical candle content while keeping the drawing canvas the size of the visible viewport.
///
/// Counter-positioning contentView by contentOffset avoids allocating a canvas as wide as the entire history.
/// Insets place half a viewport of breathing room before and after the logical candle sequence.
final class ChartScrollView: UIScrollView {
    final class ContentView: CanvasView { }
    
    /// Previous logical width used to preserve the visible history when candles are prepended.
    private var oldContentWidth: CGFloat = 0
    private let rightEdgeTolerance: CGFloat = 2
    
    override var contentSize: CGSize {
        didSet { oldContentWidth = oldValue.width }
    }
    
    let contentView = ContentView()
    
    var onLayoutChanged: ((UIScrollView) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        alwaysBounceHorizontal = true
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        delaysContentTouches = false
        alwaysBounceVertical = false
                
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(contentView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let padding = bounds.width / 2
        let inset = UIEdgeInsets(top: 0, left: padding, bottom: 0, right: padding)
        // Changing the inset can adjust contentOffset. Position the viewport canvas afterwards.
        if contentInset != inset { contentInset = inset }
        let contentFrame = CGRect(origin: CGPoint(x: contentOffset.x, y: 0), size: bounds.size)
        if contentView.frame != contentFrame { contentView.frame = contentFrame }
        contentView.layoutIfNeeded()
        onLayoutChanged?(self)
    }
}

extension ChartScrollView {
    
    enum ScrollPosition {
        case left, right, current
    }
    
    /// Whether the offset is close enough to the latest edge for live appends to keep following it.
    var isNearRightEdge: Bool {
        guard contentSize.width > 0 else { return true }
        let maxOffset = max(-contentInset.left, contentSize.width - bounds.width + contentInset.right)
        return maxOffset - contentOffset.x <= rightEdgeTolerance
    }
    
    /// Applies an edge alignment or preserves history position after content growth, then clamps to the scrollable range.
    func scroll(to scrollPosition: ScrollPosition) {
        
        var offsetX: CGFloat = 0
        if scrollPosition == .left {
            offsetX = -contentInset.left
        } else if scrollPosition == .right {
            // Align the latest candle with the configured right inset.
            offsetX = contentSize.width - frame.width + contentInset.right
        } else {
            // Preserve the historical viewport when earlier candles are prepended.
            if oldContentWidth < contentSize.width {
                offsetX = contentSize.width - (oldContentWidth - contentOffset.x)
            } else {
                offsetX = contentOffset.x
            }
        }
        
        // Clamp scrolling to the content range, including configured insets.
        let minOffset = -contentInset.left
        let maxOffset = max(minOffset, contentSize.width - frame.width + contentInset.right)
        contentOffset.x = min(max(offsetX, minOffset), maxOffset)
        setNeedsLayout()
        oldContentWidth = contentSize.width
    }
}
