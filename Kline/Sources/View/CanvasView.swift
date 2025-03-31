//
//  CanvansView.swift
//  KLine
//
//  Created by iya on 2025/3/27.
//

import UIKit

final class CanvasView: UIView {
    
    let canvas = CALayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
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
