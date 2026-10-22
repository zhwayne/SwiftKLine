//
//  SnapshotProvider.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2026/10/21.
//

import Foundation

/// A finite application-owned candle snapshot, suitable for static charts and previews.
public final class SnapshotProvider: ChartItemProvider, Sendable {
    private let items: [any ChartItem]
    /// Optional fixed bucket duration; nil preserves exact candle-open timestamps.
    public let candlePeriod: ChartPeriod?
    /// Captures a finite candle snapshot, leaving normalization to the chart loader.
    public init(items: [any ChartItem], candlePeriod: ChartPeriod? = nil) {
        self.items = items; self.candlePeriod = candlePeriod
    }
    public func fetchChartItems(forPage page: Int) async throws -> [any ChartItem] { page == 0 ? items : [] }
    public func fetchChartItems(from start: Date, to end: Date) async throws -> [any ChartItem] {
        items.filter { Date(timeIntervalSince1970: Double($0.timestamp)) >= start
            && Date(timeIntervalSince1970: Double($0.timestamp)) <= end }
    }
}
