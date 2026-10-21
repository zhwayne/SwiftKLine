//
//  ChartItemProvider.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2025/04/13.
//

import Foundation

/// An application-owned source of historical candles and optional live snapshots.
///
/// The loader may fetch history and consume live data concurrently. Implementations must be Sendable
/// and should cooperate with task cancellation. Transport, authentication, and reconnection belong to the provider.
public protocol ChartItemProvider: AnyObject, Sendable {
    /// An optional fixed Unix-time bucket duration used to match unaligned snapshots.
    ///
    /// Nil, the default, matches exact candle-open timestamps. Prefer nil for exchange calendar periods
    /// such as months; a fixed duration does not describe their calendar boundaries.
    var candlePeriod: ChartPeriod? { get }

    /// Fetches one historical page, with page zero representing the newest history.
    ///
    /// Increasing page indexes move into the past. An empty result ends pagination; overlapping timestamps
    /// are allowed and normalized by the chart. A thrown error leaves the page available for retry.
    /// - Parameter page: A zero-based page index.
    /// - Returns: Complete candle snapshots in any order.
    func fetchChartItems(forPage page: Int) async throws -> [any ChartItem]

    /// Fetches an inclusive interval used to recover missing data before reconnecting the live stream.
    ///
    /// - Parameters:
    ///   - start: Inclusive start time.
    ///   - end: Inclusive end time.
    /// - Returns: Complete snapshots covering the available portion of the interval.
    func fetchChartItems(from start: Date, to end: Date) async throws -> [any ChartItem]

    /// Creates an optional stream of complete candle snapshots; the default implementation finishes immediately.
    ///
    /// A new subscription must be usable after a previous one terminates. Cancel independent producer tasks
    /// and release sockets in the continuation’s onTermination handler. Choose buffering or aggregation
    /// according to whether the feed allows intermediate snapshots to be dropped.
    func liveStream() -> AsyncStream<any ChartItem>
}

public extension ChartItemProvider {
    /// An optional fixed Unix-time bucket duration used to match unaligned snapshots.
    ///
    /// Nil, the default, matches exact candle-open timestamps. Prefer nil for exchange calendar periods
    /// such as months; a fixed duration does not describe their calendar boundaries.
    var candlePeriod: ChartPeriod? { nil }

    /// Creates an optional stream of complete candle snapshots; the default implementation finishes immediately.
    ///
    /// A new subscription must be usable after a previous one terminates. Cancel independent producer tasks
    /// and release sockets in the continuation’s onTermination handler. Choose buffering or aggregation
    /// according to whether the feed allows intermediate snapshots to be dropped.
    func liveStream() -> AsyncStream<any ChartItem> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
