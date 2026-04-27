//
//  KLineGroupDrawCoordinator.swift
//  SwiftKLine
//
//  Created by zhwayne on 2026/4/27.
//

import UIKit

@MainActor
struct KLineGroupDrawCoordinator {
    func dataBounds(
        for renderers: [AnyRenderer],
        context: RendererContext<any KLineItem>
    ) -> (bounds: MetricBounds, cost: CFTimeInterval) {
        var dataBounds: MetricBounds = .empty
        let start = CACurrentMediaTime()
        for renderer in renderers {
            dataBounds.merge(other: renderer.dataBounds(context: context))
        }
        return (dataBounds, CACurrentMediaTime() - start)
    }

    func drawRenderers(
        _ renderers: [AnyRenderer],
        canvas: CALayer,
        context: RendererContext<any KLineItem>
    ) -> CFTimeInterval {
        let start = CACurrentMediaTime()
        for renderer in renderers {
            renderer.draw(in: canvas, context: context)
        }
        return CACurrentMediaTime() - start
    }
}
