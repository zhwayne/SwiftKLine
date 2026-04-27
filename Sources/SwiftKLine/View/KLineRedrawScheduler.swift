//
//  KLineRedrawScheduler.swift
//  SwiftKLine
//
//  Created by zhwayne on 2026/4/27.
//

import Foundation

enum KLineRedrawMode {
    case crosshairOnly
    case full

    func merged(with newValue: KLineRedrawMode) -> KLineRedrawMode {
        if self == .full || newValue == .full {
            return .full
        }
        return .crosshairOnly
    }
}

@MainActor
final class KLineRedrawScheduler {
    private var isScheduled = false
    private var pendingMode: KLineRedrawMode = .full

    func schedule(_ mode: KLineRedrawMode, draw: @escaping @MainActor (KLineRedrawMode) -> Void) {
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
