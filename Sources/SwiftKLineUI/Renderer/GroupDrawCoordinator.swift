//
//  GroupDrawCoordinator.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/04/27.
//

import SwiftKLineCore
import UIKit

/// Separates visible-bound calculation from drawing while recording debug timing for each phase.
@MainActor
struct GroupDrawCoordinator {
    /// Combines renderer ranges using the empty merge identity and returns elapsed bound-calculation time.
    func dataBounds(
        for renderers: [AnyRenderer],
        context: ChartContext
    ) -> (bounds: ValueBounds, cost: CFTimeInterval) {
        var dataBounds: ValueBounds = .empty
        let start = CACurrentMediaTime()
        for renderer in renderers {
            dataBounds.merge(other: renderer.dataBounds(context: context))
        }
        return (dataBounds, CACurrentMediaTime() - start)
    }

    /// Invokes installed renderers with the current group context and returns total draw-call time.
    func drawRenderers(
        _ renderers: [AnyRenderer],
        canvas: CALayer,
        context: ChartContext
    ) -> CFTimeInterval {
        let start = CACurrentMediaTime()
        for renderer in renderers {
            renderer.draw(in: canvas, context: context)
        }
        return CACurrentMediaTime() - start
    }
}
