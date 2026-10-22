//
//  IchimokuCalculator.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2026/10/22.
//

import Foundation

/// The five Ichimoku Kinko Hyo lines corresponding to one chart position.
///
/// Values are already displaced for plotting: ``spanA`` and ``spanB`` are drawn ahead by the configured
/// displacement, while ``chikou`` is drawn behind. A line is nil while its source window or future/lagging
/// candle is unavailable, so the renderer can break paths without inventing values.
public struct IchimokuIndicatorValue: Equatable, Sendable {
    /// Tenkan-sen, the midpoint of the short-period high/low range.
    public let tenkan: Double?
    /// Kijun-sen, the midpoint of the base-period high/low range.
    public let kijun: Double?
    /// Senkou Span A, the plotted midpoint of Tenkan-sen and Kijun-sen.
    public let spanA: Double?
    /// Senkou Span B, the plotted midpoint of the long-period high/low range.
    public let spanB: Double?
    /// Chikou Span, the close plotted behind the current candle.
    public let chikou: Double?

    /// The lowest available finite line or cloud price, or nil when every line is unavailable.
    public var min: Double? {
        [tenkan, kijun, spanA, spanB, chikou].compactMap { $0 }.filter(\.isFinite).min()
    }

    /// The highest available finite line or cloud price, or nil when every line is unavailable.
    public var max: Double? {
        [tenkan, kijun, spanA, spanB, chikou].compactMap { $0 }.filter(\.isFinite).max()
    }

    /// Creates one Ichimoku output without shifting or validating the supplied prices.
    ///
    /// - Parameters:
    ///   - tenkan: The plotted Tenkan-sen price.
    ///   - kijun: The plotted Kijun-sen price.
    ///   - spanA: The plotted Senkou Span A price.
    ///   - spanB: The plotted Senkou Span B price.
    ///   - chikou: The plotted Chikou Span price.
    public init(
        tenkan: Double?,
        kijun: Double?,
        spanA: Double?,
        spanB: Double?,
        chikou: Double?
    ) {
        self.tenkan = tenkan
        self.kijun = kijun
        self.spanA = spanA
        self.spanB = spanB
        self.chikou = chikou
    }
}

/// Computes the five Ichimoku Kinko Hyo lines in one pass with O(n) rolling extremes.
///
/// Tenkan-sen and Kijun-sen are the midpoints of their respective rolling high/low windows. Senkou Span A is
/// the average of the raw Tenkan-sen and Kijun-sen values, and Senkou Span B is the midpoint of its own window;
/// both are displaced forward by `displacement` chart positions. Chikou Span is the close displaced backward,
/// which is represented here by reading the close `displacement` candles ahead of the current position.
///
/// The final `displacement` positions have no Chikou value, and displaced spans begin only after their raw
/// source windows are available. Because the trailing plot cannot extend past the last supplied candle, the
/// cloud is drawn over existing positions using source values from `displacement` candles earlier; the forecast
/// segment beyond the final candle is intentionally omitted. Nonpositive periods, a negative displacement, or
/// insufficient input produce aligned nil values.
///
/// A changed candle can alter subsequent windows, displacements, and future reads, so the calculator relies on
/// the protocol’s full-recalculation default for updates.
public struct IchimokuCalculator: IndicatorCalculator {
    /// The Tenkan-sen lookback; positive values are required.
    public let tenkanPeriod: Int
    /// The Kijun-sen lookback; positive values are required.
    public let kijunPeriod: Int
    /// The Senkou Span B lookback; positive values are required.
    public let senkouBPeriod: Int
    /// The forward/backward plot displacement; zero is allowed.
    public let displacement: Int

    /// The stable series key, including every period and the displacement.
    public var id: SeriesKey {
        .ichimoku(
            tenkanPeriod: tenkanPeriod,
            kijunPeriod: kijunPeriod,
            senkouBPeriod: senkouBPeriod,
            displacement: displacement
        )
    }

    /// Stores the calculator parameters; validity is checked while calculating.
    ///
    /// - Parameters:
    ///   - tenkanPeriod: The Tenkan-sen lookback.
    ///   - kijunPeriod: The Kijun-sen lookback.
    ///   - senkouBPeriod: The Senkou Span B lookback.
    ///   - displacement: The number of chart positions used to shift spans forward and Chikou backward.
    public init(
        tenkanPeriod: Int = 9,
        kijunPeriod: Int = 26,
        senkouBPeriod: Int = 52,
        displacement: Int = 26
    ) {
        self.tenkanPeriod = tenkanPeriod
        self.kijunPeriod = kijunPeriod
        self.senkouBPeriod = senkouBPeriod
        self.displacement = displacement
    }

    /// Calculates an input-aligned Ichimoku output.
    ///
    /// - Parameter items: Chronological input candles.
    /// - Returns: One optional value per input index; the value itself carries the available lines.
    public func calculate(for items: [any ChartItem]) -> [IchimokuIndicatorValue?] {
        let count = items.count
        guard tenkanPeriod > 0, kijunPeriod > 0, senkouBPeriod > 0, displacement >= 0 else {
            return Array(repeating: nil, count: count)
        }

        var rawTenkan = [Double?](repeating: nil, count: count)
        var rawKijun = [Double?](repeating: nil, count: count)
        var rawSpanA = [Double?](repeating: nil, count: count)
        var rawSpanB = [Double?](repeating: nil, count: count)

        var tenkanWindow = RollingMidpoint()
        var kijunWindow = RollingMidpoint()
        var spanBWindow = RollingMidpoint()

        for i in items.indices {
            if i & 1023 == 0, Task.isCancelled { break }
            let item = items[i]
            tenkanWindow.append(
                index: i, high: item.high, low: item.low,
                droppingBefore: i - tenkanPeriod + 1
            )
            kijunWindow.append(
                index: i, high: item.high, low: item.low,
                droppingBefore: i - kijunPeriod + 1
            )
            spanBWindow.append(
                index: i, high: item.high, low: item.low,
                droppingBefore: i - senkouBPeriod + 1
            )

            if i >= tenkanPeriod - 1 { rawTenkan[i] = tenkanWindow.midpoint }
            if i >= kijunPeriod - 1 { rawKijun[i] = kijunWindow.midpoint }
            if i >= senkouBPeriod - 1 { rawSpanB[i] = spanBWindow.midpoint }
            if let tenkan = rawTenkan[i], let kijun = rawKijun[i] {
                rawSpanA[i] = (tenkan + kijun) / 2
            }
        }

        var values = [IchimokuIndicatorValue?](repeating: nil, count: count)
        for i in items.indices {
            let sourceIndex = i - displacement
            let spanA = sourceIndex >= 0 ? rawSpanA[sourceIndex] : nil
            let spanB = sourceIndex >= 0 ? rawSpanB[sourceIndex] : nil
            let forward = i.addingReportingOverflow(displacement)
            let chikou = forward.overflow || forward.partialValue >= count
                ? nil : items[forward.partialValue].close

            guard rawTenkan[i] != nil || rawKijun[i] != nil || spanA != nil
                    || spanB != nil || chikou != nil else { continue }
            values[i] = IchimokuIndicatorValue(
                tenkan: rawTenkan[i],
                kijun: rawKijun[i],
                spanA: spanA,
                spanB: spanB,
                chikou: chikou
            )
        }
        return values
    }
}

/// Maintains monotonic candidate indexes for one rolling high/low midpoint.
///
/// Each candle index enters and leaves the deques at most once, so all midpoints for a full history cost O(n)
/// rather than O(n × period). The deques store the extremes themselves, which keeps the helper independent of
/// the input storage.
private struct RollingMidpoint {
    private var maximums = RollingDeque<(index: Int, value: Double)>()
    private var minimums = RollingDeque<(index: Int, value: Double)>()

    /// Adds one candle and discards candidates that fell out of the rolling window.
    ///
    /// - Parameters:
    ///   - index: The absolute candle index entering the window.
    ///   - high: The candle high.
    ///   - low: The candle low.
    ///   - lowerBound: The first index still inside the window.
    mutating func append(index: Int, high: Double, low: Double, droppingBefore lowerBound: Int) {
        while let first = maximums.first, first.index < lowerBound { maximums.removeFirst() }
        while let first = minimums.first, first.index < lowerBound { minimums.removeFirst() }
        while let last = maximums.last, last.value <= high { maximums.removeLast() }
        maximums.append((index, high))
        while let last = minimums.last, last.value >= low { minimums.removeLast() }
        minimums.append((index, low))
    }

    /// The midpoint of the current window’s highest high and lowest low, or nil when unavailable.
    var midpoint: Double? {
        guard let high = maximums.first?.value, let low = minimums.first?.value,
              high.isFinite, low.isFinite else { return nil }
        return (high + low) / 2
    }
}
