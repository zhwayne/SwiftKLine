import Foundation

/// Williams %R in O(n), on the international -100...0 scale.
/// The first output is at period - 1. Flat high/low windows are unavailable (nil).
public struct WRCalculator: IndicatorCalculator {
    public let period: Int
    public var id: SeriesKey { .wr(period: period) }

    public init(period: Int = 14) { self.period = period }

    public func calculate(for items: [any ChartItem]) -> [Double?] {
        var result = [Double?](repeating: nil, count: items.count)
        guard period > 0, period <= items.count else { return result }
        var window = RollingExtremes()
        for i in items.indices {
            if i & 1023 == 0, Task.isCancelled { return result }
            window.append(index: i, high: items[i].high, low: items[i].low, period: period)
            guard i >= period - 1, let range = window.range, range.high != range.low else { continue }
            result[i] = finiteIndicatorValue(-100 * (range.high - items[i].close) / (range.high - range.low))
        }
        return result
    }
}
