//
//  VisibleContentCoordinator.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/04/27.
//

import SwiftKLineCore
import UIKit

/// Coordinates group bounds, legend space, and drawable viewport geometry for one visible-content pass.
@MainActor
struct VisibleContentCoordinator {
    typealias LegendConfigurator = (_ group: RendererGroup, _ groupIndex: Int, _ groupFrame: CGRect) -> CGFloat

    /// Refreshes legend and section frames without rebuilding price paths; only valid for a crosshair-only redraw.
    func updateCrosshairFastPath(
        descriptor: inout ChartDescriptor,
        contentRect: CGRect,
        context: ChartContext,
        configureLegend: LegendConfigurator
    ) {
        for idx in descriptor.groups.indices {
            let groupFrame = descriptor.frameOfGroup(at: idx, rect: contentRect)
            descriptor.groups[idx].groupFrame = groupFrame
            context.groupFrame = groupFrame

            let group = descriptor.groups[idx]
            _ = configureLegend(group, idx, groupFrame)
            for renderer in group.renderers {
                (renderer.base as? LegendUpdatable)?.updateLegend(context: context)
            }
        }
    }

    /// Recomputes each group’s visible bounds, prepares legend geometry, and draws its existing renderers.
    func drawFullContent(
        descriptor: inout ChartDescriptor,
        contentRect: CGRect,
        canvas: CALayer,
        context: ChartContext,
        groupDrawCoordinator: GroupDrawCoordinator,
        configureLegend: LegendConfigurator
    ) -> (boundsCost: CFTimeInterval, rendererCost: CFTimeInterval) {
        var boundsCost: CFTimeInterval = 0
        var rendererCost: CFTimeInterval = 0

        for (idx, group) in descriptor.groups.enumerated() {
            let renderers = group.renderers

            // Combine visible series bounds for this group.
            let dataBoundsResult = groupDrawCoordinator.dataBounds(for: renderers, context: context)
            let dataBounds = dataBoundsResult.bounds
            boundsCost += dataBoundsResult.cost
            descriptor.groups[idx].dataBounds = dataBounds
            context.layout.dataBounds = dataBounds

            // Resolve the group’s frame within the viewport canvas.
            let groupFrame = descriptor.frameOfGroup(at: idx, rect: contentRect)
            descriptor.groups[idx].groupFrame = groupFrame
            context.groupFrame = groupFrame

            // Prepare legend content and reserve its vertical space.
            let viewPortOffsetY = configureLegend(group, idx, groupFrame)

            // Remove legend height and group padding from the drawing viewport.
            let groupInset = UIEdgeInsets(
                top: group.padding.top + viewPortOffsetY, left: 0,
                bottom: group.padding.bottom, right: 0
            )
            let viewPort = groupFrame.inset(by: groupInset)
            descriptor.groups[idx].viewPort = viewPort
            context.viewPort = viewPort

            // Draw reusable renderers with the prepared group context.
            rendererCost += groupDrawCoordinator.drawRenderers(
                renderers,
                canvas: canvas,
                context: context
            )
        }

        return (boundsCost, rendererCost)
    }
}
