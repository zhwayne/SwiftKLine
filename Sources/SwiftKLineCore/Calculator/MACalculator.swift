//
//  MACalculator.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2024/11/01.
//

import Foundation

/// Computes a simple moving average using a rolling sum.
///
/// The first period - 1 outputs are nil. A nonpositive period or insufficient input returns only nil values.
public struct MACalculator: IndicatorCalculator {
    /// The number of candles in the calculation period; positive values are required.
    public let period: Int
    /// The stable series key, including configured calculation parameters.
    public var id: SeriesKey { .ma(period: period) }
    /// Stores calculator parameters; validity is checked when calculating, rather than by the initializer.
    public init(period: Int) { self.period = period }

    /// Calculates an input-aligned output array.
    ///
    /// The first period - 1 outputs are nil. A nonpositive period or insufficient input returns only nil values.
    public func calculate(for items: [any ChartItem]) -> [Double?] {
        var values: [Double?] = []
        update(for: items, values: &values, from: 0)
        return values
    }

    /// Seeds the first affected window, then advances a rolling sum in O(period + changedCount) arithmetic work.
    ///
    /// The prefix before index must represent unchanged input and the same parameters. Output storage is resized
    /// to match items; invalid prefix indexes cause a rebuild. Array copying is not included in the arithmetic bound.
    public func update(for items: [any ChartItem], values: inout [Double?], from index: Int) {
        let start = prepareValues(&values, count: items.count, from: index)
        guard period > 0, items.count >= period else {
            values = Array(repeating: nil, count: items.count); return
        }
        let first = max(start, period - 1)
        for i in start..<min(first, items.count) { values[i] = nil }
        guard first < items.count else { return }
        var sum = 0.0
        for i in (first - period + 1)...first { sum += items[i].close }
        values[first] = sum / Double(period)
        for i in (first + 1)..<items.count {
            if i & 1023 == 0, Task.isCancelled { return }
            sum += items[i].close - items[i - period].close
            values[i] = sum / Double(period)
        }
    }
}
