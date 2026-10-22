//
//  BBICalculator.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2026/10/22.
//

import Foundation

/// Computes the Bull Bear Index (BBI), the equal-weight average of several simple moving averages.
///
/// The standard configuration averages MA(3), MA(6), MA(12), and MA(24). Output begins at the largest
/// component period minus one; empty or nonpositive period sets produce aligned nil values.
public struct BBICalculator: IndicatorCalculator {
    /// The moving-average periods averaged by this indicator, stored in ascending order.
    public let periods: [Int]

    /// The stable series key including the canonical period list.
    public var id: SeriesKey { .bbi(periods: periods) }

    /// Creates a BBI calculator and sorts the supplied periods for deterministic identity.
    ///
    /// - Parameter periods: The component moving-average periods. The default is the standard BBI set.
    public init(periods: [Int] = [3, 6, 12, 24]) {
        self.periods = periods.sorted()
    }

    /// Calculates one equal-weight average per candle after every component average is available.
    ///
    /// - Parameter items: Chronological input candles.
    /// - Returns: One optional BBI value per input index, including warm-up placeholders.
    public func calculate(for items: [any ChartItem]) -> [Double?] {
        var values: [Double?] = []
        update(for: items, values: &values, from: 0)
        return values
    }

    /// Rebuilds the affected suffix because one changed candle can affect every component average.
    ///
    /// Component averages are calculated independently and then averaged over the complete input. Only the
    /// suffix at or after `index` is rewritten, so an unchanged prefix remains available to callers. The
    /// arithmetic work is O(items.count × periods.count), which keeps the implementation simple while
    /// retaining cancellation checks for long histories. Output storage is resized to match the input.
    ///
    /// - Parameters:
    ///   - items: The complete, updated input.
    ///   - values: Previous aligned output, replaced or extended in place.
    ///   - index: Earliest index whose input or position changed.
    public func update(for items: [any ChartItem], values: inout [Double?], from index: Int) {
        let start = prepareValues(&values, count: items.count, from: index)
        guard !periods.isEmpty,
              periods.allSatisfy({ $0 > 0 }),
              let maximumPeriod = periods.max(),
              items.count >= maximumPeriod else {
            values = Array(repeating: nil, count: items.count)
            return
        }

        let componentValues = periods.map { MACalculator(period: $0).calculate(for: items) }
        let first = max(start, maximumPeriod - 1)
        for i in start..<min(first, items.count) { values[i] = nil }
        guard first < items.count else { return }

        for i in first..<items.count {
            if i & 1023 == 0, Task.isCancelled { return }
            var sum = 0.0
            var isComplete = true
            for component in componentValues {
                guard let value = component[i], value.isFinite else {
                    isComplete = false
                    break
                }
                sum += value
            }
            values[i] = isComplete ? sum / Double(periods.count) : nil
        }
    }
}
