//
//  ChartPlugin.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/05/17.
//

import SwiftKLineCore
import Foundation

/// A declarative chart feature with optional per-chart coordination state.
@MainActor
public protocol ChartPlugin {
    /// Optional per-chart state coordinating configuration, loading, and rendering.
    associatedtype Coordinator = Void
    /// Stable list identity, independent of changing parameters.
    var id: String { get }
    /// Creates coordination state without subscribing or installing layers.
    func makeCoordinator() -> Coordinator
    /// Synchronizes configuration and published input without blocking the main actor.
    func update(coordinator: Coordinator, context: ChartPluginContext)
    /// Cancels owned work after access to chart resources has been revoked.
    static func dismantleCoordinator(_ coordinator: Coordinator)
}

extension ChartPlugin where Coordinator == Void {
    /// Supplies no additional state for a stateless plugin.
    public func makeCoordinator() {}
}

extension ChartPlugin {
    /// Requires no cleanup unless a plugin owns tasks or subscriptions.
    public static func dismantleCoordinator(_ coordinator: Coordinator) {}
}

/// Published candles and viewport demand, never a half-computed raw candle batch.
public struct ChartPluginInput: Sendable {
    /// The semantic identity of the primary candle source.
    public let sourceID: String
    /// Candles matching the currently published indicator outputs.
    public let candles: [any ChartItem]
    /// The visible half-open time interval, or nil until valid geometry is available.
    public let visibleTimeRange: Range<Date>?
    /// Changes when candles are published; scrolling alone does not change it.
    public let revision: UInt64
    /// Whether the chart visibility and scene permit active loading.
    public let isActive: Bool
}

/// A drawing region; a plugin's lower renderers share one independent panel.
public enum PluginPanel: Sendable { case main, sub }

/// A resource declaration error local to a plugin.
public enum ChartPluginError: Error, Equatable {
    /// Two calculators in the same plugin cannot produce the same output key.
    case duplicateSeries(SeriesKey)
}
