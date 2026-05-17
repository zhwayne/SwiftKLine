//
//  RedrawScheduler.swift
//  SwiftKLine
//
//  Created by zhwayne on 2026/4/27.
//

import Foundation

enum RedrawMode {
    case crosshairOnly
    case full

    func merged(with newValue: RedrawMode) -> RedrawMode {
        if self == .full || newValue == .full {
            return .full
        }
        return .crosshairOnly
    }
}

@MainActor
final class RedrawScheduler {
    private var isScheduled = false
    private var pendingMode: RedrawMode = .full

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
