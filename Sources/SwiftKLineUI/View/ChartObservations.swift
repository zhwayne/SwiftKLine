//
//  ChartObservations.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/10/21.
//

import Foundation

/// Owns notification tokens on the main actor so asynchronous chart teardown can remove them safely.
@MainActor
final class ChartObservations {
    private var tokens: [any NSObjectProtocol] = []
    /// Retains a token until explicit removal during chart teardown.
    func insert(_ token: any NSObjectProtocol) { tokens.append(token) }
    /// Unregisters all retained observers and releases their tokens.
    func removeAll() {
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
        tokens.removeAll()
    }
}
