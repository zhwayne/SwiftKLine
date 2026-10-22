import Foundation

/// One KDJ sample. J is intentionally not clamped to the K/D range.
public struct KDJIndicatorValue: Equatable, Sendable {
    public let k: Double
    public let d: Double
    public let j: Double

    public init(k: Double, d: Double, j: Double) {
        self.k = k
        self.d = d
        self.j = j
    }
}

/// Computes KDJ in O(n). The first output is at period - 1; K and D start at 50.
/// Flat high/low windows use RSV 50. Invalid periods produce input-aligned nil values.
public struct KDJCalculator: IndicatorCalculator {
    public let period: Int
    public let kPeriod: Int
    public let dPeriod: Int
    public var id: SeriesKey { .kdj(period: period, kPeriod: kPeriod, dPeriod: dPeriod) }

    public init(period: Int = 9, kPeriod: Int = 3, dPeriod: Int = 3) {
        self.period = period
        self.kPeriod = kPeriod
        self.dPeriod = dPeriod
    }

    public func calculate(for items: [any ChartItem]) -> [KDJIndicatorValue?] {
        var result = [KDJIndicatorValue?](repeating: nil, count: items.count)
        guard period > 0, kPeriod > 0, dPeriod > 0, period <= items.count else { return result }
        var window = RollingExtremes()
        var k = 50.0, d = 50.0
        for i in items.indices {
            if i & 1023 == 0, Task.isCancelled { return result }
            window.append(index: i, high: items[i].high, low: items[i].low, period: period)
            guard i >= period - 1, let range = window.range else { continue }
            let rsv = range.high == range.low ? 50 : 100 * (items[i].close - range.low) / (range.high - range.low)
            k += (rsv - k) / Double(kPeriod)
            d += (k - d) / Double(dPeriod)
            let j = 3 * k - 2 * d
            guard k.isFinite, d.isFinite, j.isFinite else { continue }
            result[i] = KDJIndicatorValue(k: k, d: d, j: j)
        }
        return result
    }
}
