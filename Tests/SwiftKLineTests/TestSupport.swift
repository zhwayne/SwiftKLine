//
//  TestSupport.swift
//  SwiftKLineTests
//
//  Created by zhwayne on 2026/10/21.
//

#if canImport(UIKit)
import Foundation
import UIKit
import Testing
import SwiftKLineCore
@testable import SwiftKLineUI

/// A synchronous test counter for CPU work performed by child tasks, not production async state.
final class TestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func increment() { lock.withLock { value += 1 } }
    var count: Int { lock.withLock { value } }
}

final class TestSnapshotProvider: ChartItemProvider, Sendable {
    let items: [any ChartItem]
    init(_ items: [any ChartItem]) { self.items = items }
    func fetchChartItems(forPage page: Int) async throws -> [any ChartItem] { page == 0 ? items : [] }
    func fetchChartItems(from start: Date, to end: Date) async throws -> [any ChartItem] { [] }
}

func testCandle(_ timestamp: Int, _ close: Double) -> Candle {
    Candle(timestamp: timestamp, open: close, high: close + 2, low: close - 2, close: close, volume: 100)
}

@MainActor
func testConfiguration(id: String = "test", items: [any ChartItem] = [testCandle(60, 1), testCandle(120, 2)],
                       plugins: [any ChartPlugin] = [], appearance: ChartAppearance = ChartAppearance(),
                       content: ChartType = .candlestick, indicators: IndicatorSelectionState? = nil) throws -> ChartConfiguration {
    try ChartConfiguration(source: CandleSource(id: id, duration: 60, provider: { TestSnapshotProvider(items) }),
                           appearance: appearance, content: content, plugins: plugins, indicators: indicators, features: [])
}

/// Polls a semantic condition with a deadline, not a fixed timing assumption.
@MainActor
func eventually(_ condition: () -> Bool) async -> Bool {
    for _ in 0..<2_000 {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
    return condition()
}
#endif
