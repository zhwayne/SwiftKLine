//
//  CrosshairDrawCoordinator.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/04/27.
//

import SwiftKLineCore
import UIKit

/// Resolves the crosshair’s active section and restores that section’s geometry and value range before drawing.
@MainActor
struct CrosshairDrawCoordinator {
    /// Draws only when a selected section has usable geometry; returns whether a crosshair draw was performed.
    @discardableResult
    func drawCrosshair(
        renderer: CrosshairRenderer?,
        descriptor: ChartDescriptor,
        canvas: CALayer,
        context: ChartContext,
        at location: CGPoint
    ) -> Bool {
        guard let renderer,
              let groupIndex = descriptor.indexOfGroup(at: location) else {
            return false
        }

        let group = descriptor.groups[groupIndex]
        guard !group.groupFrame.isEmpty, !group.viewPort.isEmpty else { return false }

        renderer.selectedGroup = group
        configure(renderer: renderer, descriptor: descriptor)
        context.groupFrame = group.groupFrame
        context.viewPort = group.viewPort
        context.layout.dataBounds = group.dataBounds
        renderer.draw(in: canvas, context: context)
        return true
    }

    private func configure(renderer: CrosshairRenderer, descriptor: ChartDescriptor) {
        for group in descriptor.groups {
            if group.chartSection == .mainChart {
                renderer.candleGroup = group
            } else if group.chartSection == .timeline {
                renderer.timelineGroup = group
            }
        }
    }
}
