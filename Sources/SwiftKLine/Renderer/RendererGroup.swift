//  RendererGroup.swift
//  SwiftKLine
//
//  Created by iya on 2025/4/20.

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
    var dataBounds: ValueBounds = .empty
    
    init(
        chartSection: ChartSection,
        height: CGFloat,
        padding: (CGFloat, CGFloat) = (8, 2),
        legendSpacing: CGFloat = 8,
        @RendererBuilder renderers: () -> [AnyRenderer]
    ) {
        self.chartSection = chartSection
        self.height = height
        self.padding = padding
        self.legendSpacing = legendSpacing
        self.renderers = Self._sortedRenderers(renderers())
    }

    init(
        chartSection: ChartSection,
        height: CGFloat,
        padding: (CGFloat, CGFloat) = (8, 2),
        legendSpacing: CGFloat = 8,
        renderers: [AnyRenderer] = []
    ) {
        self.chartSection = chartSection
        self.height = height
        self.padding = padding
        self.legendSpacing = legendSpacing
        self.renderers = Self._sortedRenderers(renderers)
    }

    private static func _sortedRenderers(_ renderers: [AnyRenderer]) -> [AnyRenderer] {
        renderers
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.zIndex == rhs.element.zIndex {
                    return lhs.offset < rhs.offset
                }
                return lhs.element.zIndex < rhs.element.zIndex
            }
            .map(\.element)
    }
}