//
//  KLineCrosshairDrawCoordinator.swift
//  SwiftKLine
//
//  Created by zhwayne on 2026/4/27.
//

import UIKit

@MainActor
struct KLineCrosshairDrawCoordinator {
    @discardableResult
    func drawCrosshair(
        renderer: CrosshairRenderer?,
        descriptor: ChartDescriptor,
        canvas: CALayer,
        context: RendererContext<any KLineItem>,
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
