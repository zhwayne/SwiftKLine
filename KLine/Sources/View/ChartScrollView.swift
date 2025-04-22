//
//  ChartScrollView.swift
//  KLine
//
//  Created by iya on 2025/3/22.
//

import Foundation
import UIKit

public enum ScrollPosition {
    case left, right, current
}

final class ChartScrollView: UIScrollView {
    final class ContentView: CanvasView { }
    
    private var oldContentWidth: CGFloat = 0
    
    override var contentSize: CGSize {
        didSet { oldContentWidth = oldValue.width }
    }
    
    let contentView = ContentView()
    
    var onLayoutChanged: ((UIScrollView) -> Void)?
    
    // pinch
    private var pinchCenterX: CGFloat = 0
    private var oldScale: CGFloat = 1
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        alwaysBounceHorizontal = true
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        delaysContentTouches = false
        alwaysBounceVertical = false
                
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(contentView)
        
        // pinch
        let pinch = UIPinchGestureRecognizer(
            target: self,
            action: #selector(Self.handlePinch(_:))
        )
        contentView.addGestureRecognizer(pinch)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let origin = CGPoint(x: contentOffset.x, y: 0)
        let contentFrame = CGRect(origin: origin, size: bounds.size)
        contentView.frame = contentFrame
        let padding = (bounds.width) / 2
        contentInset = UIEdgeInsets(top: 0, left: padding, bottom: 0, right: padding)
        onLayoutChanged?(self)
    }
    
    @objc private func handlePinch(_ pinch: UIPinchGestureRecognizer) {
//        switch pinch.state {
//        case .began:
//            isScrollEnabled = false
//            let p1 = pinch.location(ofTouch: 0, in: contentView)
//            let p2 = pinch.location(ofTouch: 1, in: contentView)
//            pinchCenterX = (p1.x + p2.x) / 2
//            oldScale = 1.0
//        case .changed:
//            break;
//            
//        default:
//            isScrollEnabled = true
//        }
//        
//        let difValue = pinch.scale - oldScale
//        
//        let newLineWidth = candleStyle.width * (difValue + 1)
//        let newGap = candleStyle.gap * (difValue + 1)
//        guard (1...32).contains(newLineWidth) else { return }
//        
//        styleManager.candleStyle.width = newLineWidth
//        styleManager.candleStyle.gap = newGap
//        oldScale = pinch.scale
//        
//        // 更新 contentSize
//        let contentOffsetAtPinch = contentOffset.x + pinchCenterX
//        let oldContentSize = contentSize
//        contentSize = layout.contentSize
//        
//        
//        // 算新的内容偏移量
//        let scale = contentSize.width / oldContentSize.width
//        let newContentOffsetAtPinch = contentOffsetAtPinch * scale
//        var newContentOffsetX = newContentOffsetAtPinch - pinchCenterX
//        
//        // 限制偏移量的范围
//        newContentOffsetX = max(-contentInset.left, newContentOffsetX)
//        let maxContentOffsetX = contentSize.width - bounds.width + contentInset.right
//        newContentOffsetX = min(maxContentOffsetX, newContentOffsetX)
//
//        // 更新 contentOffset 并重绘内容
//        if contentOffset.x == newContentOffsetX {
//            setNeedsLayout()
//            layoutIfNeeded()
//            delegate?.scrollViewDidScroll?(self)
//        } else {
//            contentOffset.x = newContentOffsetX
//        }
    }
}

extension ChartScrollView {
    
    func scroll(to scrollPosition: ScrollPosition) {
        
        var offsetX: CGFloat = 0
        if scrollPosition == .left {
            offsetX = -contentInset.left
        } else if scrollPosition == .right {
            // 显示最后一屏
            offsetX = contentSize.width - frame.width + contentInset.right
        } else {
            // 保持当前显示位置不变
            if oldContentWidth < contentSize.width {
                offsetX = contentSize.width - (oldContentWidth - contentOffset.x)
            } else {
                offsetX = contentOffset.x
            }
        }
        
        // 设置新的 contentOffset，确保不超出范围
        contentOffset.x = offsetX
        oldContentWidth = contentSize.width
    }
}
