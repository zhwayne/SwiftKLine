//
//  EMACalculator.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2024/11/06.
//

import Foundation

/// Computes an exponential moving average with the library’s expanding-mean warm-up convention.
///
/// The first period candles use expanding means; subsequent values use alpha = 2 / (period + 1). A nonpositive period returns nil.
public struct EMACalculator: IndicatorCalculator {
    /// The number of candles in the calculation period; positive values are required.
    public let period: Int
    /// The stable series key, including configured calculation parameters.
    public var id: SeriesKey { .ema(period: period) }
    /// Stores calculator parameters; validity is checked when calculating, rather than by the initializer.
    public init(period: Int) { self.period = period }

    /// Calculates an input-aligned output array.
    ///
    /// The first period candles use expanding means; subsequent values use alpha = 2 / (period + 1). A nonpositive period returns nil.
    public func calculate(for items: [any ChartItem]) -> [Double?] {
        var values: [Double?] = []
        update(for: items, values: &values, from: 0)
        return values
    }

    /// Restores the preceding EMA and recalculates the affected suffix. A missing seed forces a full rebuild.
    ///
    /// The prefix before index must represent unchanged input and the same parameters. Output storage is resized
    /// to match items; invalid prefix indexes cause a rebuild. Array copying is not included in the arithmetic bound.
    public func update(for items: [any ChartItem], values: inout [Double?], from index: Int) {
        var start = prepareValues(&values, count: items.count, from: index)
        guard period > 0 else { values = Array(repeating: nil, count: items.count); return }
        if start > 0, values[start - 1] == nil { start = 0 }
        var previous = start > 0 ? values[start - 1] ?? 0 : 0
        var sum = previous * Double(start)
        let alpha = 2 / (Double(period) + 1)
        for i in start..<items.count {
            if i & 1023 == 0, Task.isCancelled { return }
            if i < period {
                sum += items[i].close
                previous = sum / Double(i + 1)
            } else {
                previous += (items[i].close - previous) * alpha
            }
            values[i] = previous
        }
    }
}
