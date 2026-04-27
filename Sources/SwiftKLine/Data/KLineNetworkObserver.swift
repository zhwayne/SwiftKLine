//
//  KLineNetworkObserver.swift
//  SwiftKLine
//

import Foundation
import Network

@MainActor
final class KLineNetworkObserver {
    enum Status: Equatable {
        case available
        case unavailable
    }

    var statusDidChange: ((Status) -> Void)?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "SwiftKLine.NetworkObserver")
    private var currentStatus: Status = .available
    private var isStarted = false

    func start() {
        guard !isStarted else { return }
        isStarted = true
        monitor.pathUpdateHandler = { [weak self] path in
            let status: Status = path.status == .satisfied ? .available : .unavailable
            Task { @MainActor in
                self?.apply(status)
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        guard isStarted else { return }
        monitor.cancel()
        isStarted = false
    }

    private func apply(_ status: Status) {
        guard status != currentStatus else { return }
        currentStatus = status
        statusDidChange?(status)
    }
}
