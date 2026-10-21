//
//  CanvasView.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2025/03/27.
//

import SwiftKLineCore
import UIKit

/// Hosts a reusable Core Animation canvas whose bounds follow the viewport-sized view.
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
    
    /// Removes all canvas sublayers; owners must reinstall renderer layers before drawing again.
    func clean() {
        canvas.sublayers = nil
    }
}
