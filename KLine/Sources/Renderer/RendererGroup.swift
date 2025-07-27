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
    let chartSection: ChartSection
    let legendSpacing: CGFloat
    
    typealias Builder = RendererBuilder
    
    init(
        chartSection: ChartSection,
        height: CGFloat,
        padding: (CGFloat, CGFloat) = (8, 2),
        legendSpacing: CGFloat = 8,
        @Builder renderers: () -> [AnyRenderer]
    ) {
        self.chartSection = chartSection
        self.height = height
        self.padding = padding
        self.legendSpacing = legendSpacing
        self.renderers = renderers()
    }
}

//extension RendererGroup {
//    
//    var legendFrame: CGRect {
//        var frame = legendLayer.frame
//        guard let string = legendLayer.string as? NSAttributedString,
//              !string.string.isEmpty else {
//            frame.size = .zero
//            return .zero
//        }
//        return frame
//    }
//}
