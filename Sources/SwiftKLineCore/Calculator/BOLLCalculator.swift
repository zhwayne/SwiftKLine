//
//  BOLLCalculator.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2025/08/06.
//

import Foundation

/// The three Bollinger-band prices corresponding to one input candle.
public struct BOLLIndicatorValue: Equatable, Sendable {
    /// The moving mean of close prices.
    public let middle: Double
    /// The moving mean plus k times the population standard deviation.
    public let upper: Double
    /// The moving mean minus k times the population standard deviation.
    public let lower: Double
    /// The minimum band price, used when combining visible drawing bounds.
    public var min: Double { Swift.min(lower, middle, upper) }
    /// The maximum band price, used when combining visible drawing bounds.
    public var max: Double { Swift.max(lower, middle, upper) }

    /// Creates one band output without validating or reordering the supplied prices.
    public init(middle: Double, upper: Double, lower: Double) {
        self.middle = middle; self.upper = upper; self.lower = lower
    }
}

/// Computes Bollinger bands using a moving mean and population standard deviation.
///
/// The first period - 1 outputs are nil. Invalid periods, negative or non-finite k, and insufficient input produce nil.
public struct BOLLCalculator: IndicatorCalculator {
    /// The number of candles in the calculation period; positive values are required.
    public let period: Int
    /// The finite, nonnegative multiplier applied to the population standard deviation.
    public let k: Double
    /// The stable series key, including configured calculation parameters.
    public var id: SeriesKey { .boll(period: period, k: k) }
    /// Stores calculator parameters; validity is checked when calculating, rather than by the initializer.
    public init(period: Int = 20, k: Double = 2) { self.period = period; self.k = k }

    /// Calculates an input-aligned output array.
    ///
    /// The first period - 1 outputs are nil. Invalid periods, negative or non-finite k, and insufficient input produce nil.
    public func calculate(for items: [any ChartItem]) -> [BOLLIndicatorValue?] {
        var values: [BOLLIndicatorValue?] = []
        update(for: items, values: &values, from: 0)
        return values
    }

    /// Uses rolling Welford removal/addition and periodic rebasing to limit cancellation error while retaining O(n) full-calculation work.
    ///
    /// The prefix before index must represent unchanged input and the same parameters. Output storage is resized
    /// to match items; invalid prefix indexes cause a rebuild. Array copying is not included in the arithmetic bound.
    public func update(for items: [any ChartItem], values: inout [BOLLIndicatorValue?], from index: Int) {
        let start = prepareValues(&values, count: items.count, from: index)
        guard period > 0, k.isFinite, k >= 0, items.count >= period else {
            values = Array(repeating: nil, count: items.count); return
        }
        let first = max(start, period - 1)
        for i in start..<min(first, items.count) { values[i] = nil }
        guard first < items.count else { return }
        var mean = 0.0
        var m2 = 0.0
        for i in first..<items.count {
            if i & 1023 == 0, Task.isCancelled { return }
            // Periodic rebasing bounds accumulated rounding error and still takes O(n) total work.
            if i == first || (i - first) % period == 0 {
                mean = 0; m2 = 0
                for offset in 0..<period {
                    let price = items[i - period + 1 + offset].close
                    let delta = price - mean
                    mean += delta / Double(offset + 1)
                    m2 += delta * (price - mean)
                }
            } else if period > 1 {
                let old = items[i - period].close
                let reducedMean = mean + (mean - old) / Double(period - 1)
                m2 -= (old - mean) * (old - reducedMean)
                let delta = items[i].close - reducedMean
                mean = reducedMean + delta / Double(period)
                m2 += delta * (items[i].close - mean)
            }
            let deviation = sqrt(max(0, m2) / Double(period)) * k
            values[i] = BOLLIndicatorValue(middle: mean, upper: mean + deviation, lower: mean - deviation)
        }
    }
}
