//
//  GroupDrawCoordinator.swift
//  SwiftKLine
//
//  Created by zhwayne on 2026/4/27.
//

import UIKit

@MainActor
struct GroupDrawCoordinator {
    func dataBounds(
        for renderers: [AnyRenderer],
        context: RendererContext
    ) -> (bounds: ValueBounds, cost: CFTimeInterval) {
        var dataBounds: ValueBounds = .empty
        let start = CACurrentMediaTime()
        for renderer in renderers {
            dataBounds.merge(other: renderer.dataBounds(context: context))
        }
        return (dataBounds, CACurrentMediaTime() - start)
    }

    func drawRenderers(
        _ renderers: [AnyRenderer],
        canvas: CALayer,
        context: RendererContext
    ) -> CFTimeInterval {
        let start = CACurrentMediaTime()
        for renderer in renderers {
            renderer.draw(in: canvas, context: context)
        }
        return CACurrentMediaTime() - start
    }
}
