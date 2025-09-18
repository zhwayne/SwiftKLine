//
//  RendererGroup.swift
//  SwiftKLine
//
//  Created by iya on 2025/4/20.
//

import Foundation
import UIKit

@MainActor
struct RendererGroup {
    
    let height: CGFloat
    let padding: (top: CGFloat, bottom: CGFloat)
    var renderers: [AnyRenderer]
    let chartSection: ChartSection
    let legendSpacing: CGFloat
    
    var viewPort: CGRect = .zero
    var groupFrame: CGRect = .zero
    var dataBounds: MetricBounds = .empty
    
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
