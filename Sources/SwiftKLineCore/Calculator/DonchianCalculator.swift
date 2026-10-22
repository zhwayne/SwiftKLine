//
//  DonchianCalculator.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2026/10/22.
//

import Foundation

/// Computes a Donchian channel from rolling highs and lows.
///
/// The upper line is the highest high in the lookback window, the lower line is the lowest low, and the
/// middle line is their midpoint. The first period - 1 outputs are nil. A nonpositive period or insufficient
/// input produces aligned nil values.
public struct DonchianCalculator: IndicatorCalculator {
    /// The number of candles in the rolling high/low window; positive values are required.
    public let period: Int

    /// The stable series key, including the configured lookback period.
    public var id: SeriesKey { .donchian(period: period) }

    /// Stores the calculator parameters; validity is checked while calculating.
    ///
    /// - Parameter period: The number of candles in the rolling high/low window.
    public init(period: Int = 20) {
        self.period = period
    }

    /// Calculates an input-aligned channel output.
    ///
    /// - Parameter items: Chronological input candles.
    /// - Returns: One optional Donchian value per input index, including warm-up placeholders.
    public func calculate(for items: [any ChartItem]) -> [BandIndicatorValue?] {
        var values: [BandIndicatorValue?] = []
        update(for: items, values: &values, from: 0)
        return values
    }

    /// Rebuilds the affected windows using monotonic high and low queues in O(period + changedCount).
    ///
    /// A change at index can affect outputs through index + period - 1. The calculation therefore restarts
    /// at `index - period + 1` (clamped to the first complete window) and preserves all earlier prefix values.
    /// The monotonic queues keep each high and low index at most once, so a full history costs O(n) rather
    /// than O(n × period).
    ///
    /// - Parameters:
    ///   - items: The complete, updated input.
    ///   - values: Previous aligned output, replaced or extended in place.
    ///   - index: Earliest index whose input or position changed.
    public func update(for items: [any ChartItem], values: inout [BandIndicatorValue?], from index: Int) {
        let start = prepareValues(&values, count: items.count, from: index)
        guard period > 0, items.count >= period else {
            values = Array(repeating: nil, count: items.count)
            return
        }

        let first = max(start, period - 1)
        for i in start..<min(first, items.count) { values[i] = nil }
        guard first < items.count else { return }

        var maximums = RollingDeque<Int>()
        var minimums = RollingDeque<Int>()
        maximums.reserveCapacity(period)
        minimums.reserveCapacity(period)

        let windowStart = first - period + 1
        for i in windowStart...first {
            appendMaximum(at: i, items: items, to: &maximums)
            appendMinimum(at: i, items: items, to: &minimums)
        }
        values[first] = channel(maximums: maximums, minimums: minimums, items: items)

        for i in (first + 1)..<items.count {
            if i & 1023 == 0, Task.isCancelled { return }
            let expired = i - period
            while let head = maximums.first, head <= expired { maximums.removeFirst() }
            while let head = minimums.first, head <= expired { minimums.removeFirst() }
            appendMaximum(at: i, items: items, to: &maximums)
            appendMinimum(at: i, items: items, to: &minimums)
            values[i] = channel(maximums: maximums, minimums: minimums, items: items)
        }
    }

    /// Appends one high index while maintaining a decreasing deque of candidate maxima.
    ///
    /// - Parameters:
    ///   - index: Candle index entering the window.
    ///   - items: The complete input sequence.
    ///   - maximums: Monotonic deque of indexes ordered by decreasing high.
    private func appendMaximum(
        at index: Int,
        items: [any ChartItem],
        to maximums: inout RollingDeque<Int>
    ) {
        let high = items[index].high
        while let last = maximums.last, items[last].high <= high {
            maximums.removeLast()
        }
        maximums.append(index)
    }

    /// Appends one low index while maintaining an increasing deque of candidate minima.
    ///
    /// - Parameters:
    ///   - index: Candle index entering the window.
    ///   - items: The complete input sequence.
    ///   - minimums: Monotonic deque of indexes ordered by increasing low.
    private func appendMinimum(
        at index: Int,
        items: [any ChartItem],
        to minimums: inout RollingDeque<Int>
    ) {
        let low = items[index].low
        while let last = minimums.last, items[last].low >= low {
            minimums.removeLast()
        }
        minimums.append(index)
    }

    /// Builds the current channel from the front of both monotonic queues.
    ///
    /// - Parameters:
    ///   - maximums: Monotonic queue whose first index owns the window's highest high.
    ///   - minimums: Monotonic queue whose first index owns the window's lowest low.
    ///   - items: The complete input sequence.
    /// - Returns: The upper, middle, and lower channel prices.
    private func channel(
        maximums: RollingDeque<Int>,
        minimums: RollingDeque<Int>,
        items: [any ChartItem]
    ) -> BandIndicatorValue? {
        guard let maximum = maximums.first, let minimum = minimums.first else { return nil }
        let upper = items[maximum].high
        let lower = items[minimum].low
        return BandIndicatorValue(upper: upper, middle: (upper + lower) / 2, lower: lower)
    }
}
