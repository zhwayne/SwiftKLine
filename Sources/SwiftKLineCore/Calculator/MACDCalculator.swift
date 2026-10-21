//
//  MACDCalculator.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2025/04/01.
//

import Foundation

/// The DIF line, DEA signal, and doubled histogram corresponding to one input candle.
public struct MACDIndicatorValue: Equatable, Sendable {
    /// DIF: the fast EMA minus the slow EMA.
    public let macd: Double
    /// DEA: the smoothed DIF signal.
    public let signal: Double
    /// BAR: twice the difference between DIF and DEA, matching the library’s existing histogram convention.
    public let histogram: Double
    /// The minimum among DIF, DEA, and BAR.
    public var min: Double { Swift.min(macd, signal, histogram) }
    /// The maximum among DIF, DEA, and BAR.
    public var max: Double { Swift.max(macd, signal, histogram) }
    /// Creates one MACD output without transforming the supplied values.
    public init(macd: Double, signal: Double, histogram: Double) {
        self.macd = macd; self.signal = signal; self.histogram = histogram
    }
}

/// Computes DIF, DEA, and a doubled histogram in one pass with O(1) working state beyond output storage.
///
/// Uses expanding-mean EMA warm-up. The first signal appears at longPeriod + signalPeriod - 2; invalid or insufficient periods return nil.
public struct MACDCalculator: IndicatorCalculator {
    /// The positive period of the fast EMA.
    public let shortPeriod: Int
    /// The positive period of the slow EMA and the starting point for signal warm-up.
    public let longPeriod: Int
    /// The positive number of DIF values used to seed and smooth DEA.
    public let signalPeriod: Int
    /// The stable series key, including configured calculation parameters.
    public var id: SeriesKey { .macd(shortPeriod: shortPeriod, longPeriod: longPeriod, signalPeriod: signalPeriod) }
    /// Stores calculator parameters; validity is checked when calculating, rather than by the initializer.
    public init(shortPeriod: Int = 12, longPeriod: Int = 26, signalPeriod: Int = 9) {
        self.shortPeriod = shortPeriod; self.longPeriod = longPeriod; self.signalPeriod = signalPeriod
    }

    /// Calculates an input-aligned output array.
    ///
    /// Uses expanding-mean EMA warm-up. The first signal appears at longPeriod + signalPeriod - 2; invalid or insufficient periods return nil.
    public func calculate(for items: [any ChartItem]) -> [MACDIndicatorValue?] {
        var values = [MACDIndicatorValue?](repeating: nil, count: items.count)
        guard shortPeriod > 0, longPeriod > 0, signalPeriod > 0,
              items.count >= longPeriod, signalPeriod <= items.count - (longPeriod - 1) else { return values }
        let firstSignal = longPeriod - 1 + signalPeriod - 1
        let shortAlpha = 2 / (Double(shortPeriod) + 1)
        let longAlpha = 2 / (Double(longPeriod) + 1)
        let signalAlpha = 2 / (Double(signalPeriod) + 1)
        var sum = 0.0
        var shortEMA = 0.0
        var longEMA = 0.0
        var signalSum = 0.0
        var signal = 0.0
        for i in items.indices {
            if i & 1023 == 0, Task.isCancelled { return values }
            let price = items[i].close
            sum += price
            shortEMA = i < shortPeriod ? sum / Double(i + 1) : shortEMA + (price - shortEMA) * shortAlpha
            longEMA = i < longPeriod ? sum / Double(i + 1) : longEMA + (price - longEMA) * longAlpha
            let dif = shortEMA - longEMA
            if i >= longPeriod - 1, i <= firstSignal { signalSum += dif }
            guard i >= firstSignal else { continue }
            signal = i == firstSignal ? signalSum / Double(signalPeriod) : signal + (dif - signal) * signalAlpha
            values[i] = MACDIndicatorValue(macd: dif, signal: signal, histogram: 2 * (dif - signal))
        }
        return values
    }
}
