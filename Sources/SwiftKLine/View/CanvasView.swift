//
//  CanvansView.swift
//  SwiftKLine
//
//  Created by iya on 2025/3/27.
//

import UIKit

class CanvasView: UIView {
    
    let canvas = CALayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        canvas.drawsAsynchronously = true
        layer.addSublayer(canvas)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        canvas.frame = bounds
    }
    
    func clean() {
        canvas.sublayers = nil
    }
}
