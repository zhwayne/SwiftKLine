//
//  VOLCalculator.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2025/03/24.
//

import Foundation

/// Projects each candle’s traded quantity into a Double-valued volume series without a warm-up period.
public struct VOLCalculator: IndicatorCalculator {
    /// The built-in volume series key.
    public var id: SeriesKey { .vol }
    /// Creates a stateless volume projection.
    public init() {}
    /// Returns every input candle’s volume at the same index.
    public func calculate(for items: [any ChartItem]) -> [Double?] { items.map(\.volume) }

    /// Replaces or appends only the affected suffix; earlier input and output must remain aligned.
    public func update(for items: [any ChartItem], values: inout [Double?], from index: Int) {
        let start = prepareValues(&values, count: items.count, from: index)
        for i in start..<items.count { values[i] = items[i].volume }
    }
}
