import Foundation

/// On-balance volume in O(n), seeded at zero on the first candle.
/// Rising closes add volume, falling closes subtract it, and unchanged closes preserve OBV.
public struct OBVCalculator: IndicatorCalculator {
    public var id: SeriesKey { .obv }
    public init() {}

    public func calculate(for items: [any ChartItem]) -> [Double?] {
        var result = [Double?](repeating: nil, count: items.count)
        guard !items.isEmpty else { return result }
        result[0] = 0
        var total = 0.0
        for i in 1..<items.count {
            if i & 1023 == 0, Task.isCancelled { return result }
            if items[i].close > items[i - 1].close { total += items[i].volume }
            else if items[i].close < items[i - 1].close { total -= items[i].volume }
            result[i] = finiteIndicatorValue(total)
        }
        return result
    }
}
