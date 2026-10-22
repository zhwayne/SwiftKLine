//
//  VWMACalculator.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2026/10/22.
//

import Foundation

/// Computes a volume-weighted moving average (VWMA) of close prices.
///
/// Each close is weighted by its candle volume. The first period - 1 outputs are nil. A nonpositive
/// period, insufficient input, or a window whose total volume is not positive produces nil instead of
/// dividing by zero. Volumes and prices are used exactly as supplied by ``ChartItem``.
public struct VWMACalculator: IndicatorCalculator {
    /// The number of candles in the moving window; positive values are required.
    public let period: Int

    /// The stable series key, including the configured period.
    public var id: SeriesKey { .vwma(period: period) }

    /// Stores the calculator parameters; validity is checked while calculating.
    ///
    /// - Parameter period: The number of candles in the moving window.
    public init(period: Int = 20) {
        self.period = period
    }

    /// Calculates an input-aligned output array.
    ///
    /// - Parameter items: Chronological input candles.
    /// - Returns: One optional VWMA value per input index, including warm-up placeholders.
    public func calculate(for items: [any ChartItem]) -> [Double?] {
        var values: [Double?] = []
        update(for: items, values: &values, from: 0)
        return values
    }

    /// Seeds the first affected window, then advances price-volume and volume sums in O(period + changedCount).
    ///
    /// The prefix before index must represent unchanged input and the same period. Output storage is resized
    /// to match items; invalid prefix indexes cause a rebuild. Array copying is not included in the arithmetic
    /// bound. A nonpositive or non-finite volume sum yields nil for that candle without stopping the rolling
    /// state, so later candles can recover once their windows contain positive volume.
    ///
    /// - Parameters:
    ///   - items: The complete, updated input.
    ///   - values: Previous aligned output, replaced or extended in place.
    ///   - index: Earliest index whose input or position changed.
    public func update(for items: [any ChartItem], values: inout [Double?], from index: Int) {
        let start = prepareValues(&values, count: items.count, from: index)
        guard period > 0, items.count >= period else {
            values = Array(repeating: nil, count: items.count)
            return
        }

        let first = max(start, period - 1)
        for i in start..<min(first, items.count) { values[i] = nil }
        guard first < items.count else { return }

        var priceVolumeSum = 0.0
        var volumeSum = 0.0
        for offset in 0..<period {
            let item = items[first - period + 1 + offset]
            priceVolumeSum += item.close * item.volume
            volumeSum += item.volume
        }
        values[first] = average(priceVolumeSum: priceVolumeSum, volumeSum: volumeSum)

        for i in (first + 1)..<items.count {
            if i & 1023 == 0, Task.isCancelled { return }
            let added = items[i]
            let removed = items[i - period]
            priceVolumeSum += added.close * added.volume - removed.close * removed.volume
            volumeSum += added.volume - removed.volume
            values[i] = average(priceVolumeSum: priceVolumeSum, volumeSum: volumeSum)
        }
    }

    /// Converts rolling sums into a finite VWMA value, returning nil for unusable volume windows.
    ///
    /// - Parameters:
    ///   - priceVolumeSum: The rolling sum of close prices multiplied by volume.
    ///   - volumeSum: The rolling sum of volumes.
    /// - Returns: The volume-weighted average, or nil when the window cannot produce a finite positive weight.
    private func average(priceVolumeSum: Double, volumeSum: Double) -> Double? {
        guard volumeSum > 0, volumeSum.isFinite, priceVolumeSum.isFinite else { return nil }
        return priceVolumeSum / volumeSum
    }
}
