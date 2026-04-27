//
//  KLineVisibleContentCoordinator.swift
//  SwiftKLine
//
//  Created by zhwayne on 2026/4/27.
//

import UIKit

@MainActor
struct KLineVisibleContentCoordinator {
    typealias LegendConfigurator = (_ group: RendererGroup, _ groupIndex: Int, _ groupFrame: CGRect) -> CGFloat

    func updateCrosshairFastPath(
        descriptor: inout ChartDescriptor,
        contentRect: CGRect,
        context: RendererContext<any KLineItem>,
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

    func drawFullContent(
        descriptor: inout ChartDescriptor,
        contentRect: CGRect,
        canvas: CALayer,
        context: RendererContext<any KLineItem>,
        groupDrawCoordinator: KLineGroupDrawCoordinator,
        configureLegend: LegendConfigurator
    ) -> (boundsCost: CFTimeInterval, rendererCost: CFTimeInterval) {
        var boundsCost: CFTimeInterval = 0
        var rendererCost: CFTimeInterval = 0

        for (idx, group) in descriptor.groups.enumerated() {
            let renderers = group.renderers

            // 计算可见区域内数据范围
            let dataBoundsResult = groupDrawCoordinator.dataBounds(for: renderers, context: context)
            let dataBounds = dataBoundsResult.bounds
            boundsCost += dataBoundsResult.cost
            descriptor.groups[idx].dataBounds = dataBounds
            context.layout.dataBounds = dataBounds

            // 计算可见区域内每个 group 所在的位置
            let groupFrame = descriptor.frameOfGroup(at: idx, rect: contentRect)
            descriptor.groups[idx].groupFrame = groupFrame
            context.groupFrame = groupFrame

            // 绘制图例
            let viewPortOffsetY = configureLegend(group, idx, groupFrame)

            // 计算 viewPort
            let groupInset = UIEdgeInsets(
                top: group.padding.top + viewPortOffsetY, left: 0,
                bottom: group.padding.bottom, right: 0
            )
            let viewPort = groupFrame.inset(by: groupInset)
            descriptor.groups[idx].viewPort = viewPort
            context.viewPort = viewPort

            // 绘制图表
            rendererCost += groupDrawCoordinator.drawRenderers(
                renderers,
                canvas: canvas,
                context: context
            )
        }

        return (boundsCost, rendererCost)
    }
}
