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
        let origin = CGPoint(x: contentOffset.x, y: 0)
        let contentFrame = CGRect(origin: origin, size: bounds.size)
        contentView.frame = contentFrame
        let padding = (bounds.width) / 2
        contentInset = UIEdgeInsets(top: 0, left: padding, bottom: 0, right: padding)
        onLayoutChanged?(self)
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
