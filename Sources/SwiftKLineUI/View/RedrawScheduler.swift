//
//  RedrawScheduler.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/04/27.
//

import SwiftKLineCore
import Foundation

/// The minimum rendering work requested for the next coalesced drawing pass.
enum RedrawMode {
    case crosshairOnly
    case full

    /// Combines pending work so any full redraw takes precedence over a crosshair-only request.
    func merged(with newValue: RedrawMode) -> RedrawMode {
        if self == .full || newValue == .full {
            return .full
        }
        return .crosshairOnly
    }
}

/// Coalesces main-actor redraw requests into one scheduled pass.
///
/// Additional requests strengthen pendingMode without enqueueing another draw task.
@MainActor
final class RedrawScheduler {
    private var isScheduled = false
    private var pendingMode: RedrawMode = .full

    /// Queues a drawing pass if none is scheduled, merging any requests that arrive before it executes.
    func schedule(_ mode: RedrawMode, draw: @escaping @MainActor (RedrawMode) -> Void) {
        pendingMode = pendingMode.merged(with: mode)
        guard !isScheduled else { return }
        isScheduled = true
        Task { @MainActor in
            isScheduled = false
            let redrawMode = pendingMode
            pendingMode = .crosshairOnly
            draw(redrawMode)
        }
    }
}
