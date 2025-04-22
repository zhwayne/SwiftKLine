//
//  RendererGroup.swift
//  KLine
//
//  Created by iya on 2025/4/20.
//

import Foundation
import UIKit

@MainActor
struct RendererGroup {
    
    let height: CGFloat
    let padding: (top: CGFloat, bottom: CGFloat)
    let renderers: [AnyRenderer]
    private let legendLayer = CATextLayer()
    
    typealias Builder = RendererBuilder
    
    init(
        height: CGFloat,
        padding: (CGFloat, CGFloat) = (8, 2),
        @Builder renderers: () -> [AnyRenderer]
    ) {
        self.height = height
        self.padding = padding
        self.renderers = renderers()
        legendLayer.contentsScale = UIScreen.main.scale
    }
    
    func install(to layer: CALayer) {
        layer.addSublayer(legendLayer)
    }
    
    func uninstall(from layer: CALayer) {
        legendLayer.removeFromSuperlayer()
    }

    func drawLegend(groupFrame: CGRect, string: NSAttributedString) {
        var rect = CGRect(
            x: 16,
            y: 8 + groupFrame.minY,
            width: groupFrame.width - 32,
            height: groupFrame.height - 16
        )
        let boundingRect = string.boundingRect(
            with: rect.size,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        rect.size = boundingRect.size
        legendLayer.string = string
        legendLayer.frame = rect
        legendLayer.preferredFrameSize()
    }
}

extension RendererGroup {
    
    var legendFrame: CGRect {
        var frame = legendLayer.frame
        guard let string = legendLayer.string as? NSAttributedString,
              !string.string.isEmpty else {
            frame.size = .zero
            return .zero
        }
        return frame
    }
}
