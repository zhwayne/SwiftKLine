//
//  SuperTrendCalculator.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2026/10/22.
//

import Foundation

/// The active SuperTrend line and trend direction at one candle.
///
/// The value is the trailing stop that currently supports or caps price: the final lower band during an
/// uptrend and the final upper band during a downtrend. Renderers use ``isUp`` to color the line without
/// re-deriving the trend from consecutive prices.
public struct SuperTrendIndicatorValue: Equatable, Sendable {
    /// The active trailing-stop price.
    public let value: Double
    /// Whether the current trend is up; a down trend caps price with the final upper band.
    public let isUp: Bool

    /// Creates one SuperTrend output without validating or transforming the supplied state.
    ///
    /// - Parameters:
    ///   - value: The active trailing-stop price.
    ///   - isUp: Whether the current trend is up.
    public init(value: Double, isUp: Bool) {
        self.value = value
        self.isUp = isUp
    }
}

/// Computes a SuperTrend trailing stop from Wilder’s average true range.
///
/// The true range is smoothed over ``period`` candles, and the final bands ratchet with the trend: the upper
/// band can only move down while price stays below it, and the lower band can only move up while price stays
/// above it. Price crossing the active band flips the trend and switches the output to the opposite band.
///
/// The first `period - 1` outputs are nil because the ATR is not available yet. The first calculable candle
/// seeds a downtrend and emits the final upper band, matching the initialization used by common charting
/// platforms. A nonpositive period, a negative or non-finite multiplier, or insufficient input produces
/// aligned nil values.
///
/// A changed candle can alter every later band and trend state, so the calculator relies on the protocol’s
/// full-recalculation default for updates instead of carrying hidden incremental state.
public struct SuperTrendCalculator: IndicatorCalculator {
    /// The number of candles in the ATR smoothing window; positive values are required.
    public let period: Int
    /// The ATR distance of the final bands from the candle midpoint; finite, nonnegative values are required.
    public let multiplier: Double

    /// The stable series key, including both calculation parameters.
    public var id: SeriesKey { .superTrend(period: period, multiplier: multiplier) }

    /// Stores the calculator parameters; validity is checked while calculating.
    ///
    /// - Parameters:
    ///   - period: The number of candles in the ATR smoothing window.
    ///   - multiplier: The ATR distance used to place the final bands around the candle midpoint.
    public init(period: Int = 10, multiplier: Double = 3) {
        self.period = period
        self.multiplier = multiplier
    }

    /// Calculates an input-aligned SuperTrend output.
    ///
    /// - Parameter items: Chronological input candles.
    /// - Returns: One optional directional value per input index, including warm-up placeholders.
    public func calculate(for items: [any ChartItem]) -> [SuperTrendIndicatorValue?] {
        guard period > 0, multiplier.isFinite, multiplier >= 0, items.count >= period else {
            return Array(repeating: nil, count: items.count)
        }

        var values = [SuperTrendIndicatorValue?](repeating: nil, count: items.count)
        var trueRangeSum = 0.0
        var averageTrueRange: Double?
        var finalUpper = 0.0
        var finalLower = 0.0
        var isUp = false
        var previousClose: Double?

        for i in items.indices {
            if i & 1023 == 0, Task.isCancelled { break }

            let item = items[i]
            let trueRange: Double
            if let previousClose {
                trueRange = max(
                    item.high - item.low,
                    abs(item.high - previousClose),
                    abs(item.low - previousClose)
                )
            } else {
                trueRange = item.high - item.low
            }
            previousClose = item.close

            if i < period - 1 {
                trueRangeSum += trueRange
                continue
            }
            if i == period - 1 {
                averageTrueRange = (trueRangeSum + trueRange) / Double(period)
            } else if let current = averageTrueRange {
                averageTrueRange = (current * Double(period - 1) + trueRange) / Double(period)
            }

            guard let atr = averageTrueRange, atr.isFinite else { continue }
            let midpoint = (item.high + item.low) / 2
            let basicUpper = midpoint + multiplier * atr
            let basicLower = midpoint - multiplier * atr

            if i == period - 1 {
                finalUpper = basicUpper
                finalLower = basicLower
            } else {
                let previousUpper = finalUpper
                let previousLower = finalLower
                let priorClose = items[i - 1].close
                finalUpper = (basicUpper < previousUpper || priorClose > previousUpper)
                    ? basicUpper : previousUpper
                finalLower = (basicLower > previousLower || priorClose < previousLower)
                    ? basicLower : previousLower

                if isUp {
                    isUp = item.close >= finalLower
                } else {
                    isUp = item.close > finalUpper
                }
            }

            let value = isUp ? finalLower : finalUpper
            guard value.isFinite else { continue }
            values[i] = SuperTrendIndicatorValue(value: value, isUp: isUp)
        }
        return values
    }
}
