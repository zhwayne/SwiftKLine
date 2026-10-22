import Foundation

/// Wilder average true range in O(n). The first output is at period - 1.
/// The first candle's TR is high - low; the first complete TR mean seeds RMA.
public struct ATRCalculator: IndicatorCalculator {
    public let period: Int
    public var id: SeriesKey { .atr(period: period) }

    public init(period: Int = 14) { self.period = period }

    public func calculate(for items: [any ChartItem]) -> [Double?] {
        var result = [Double?](repeating: nil, count: items.count)
        guard period > 0, period <= items.count else { return result }
        var average = SeededSmoothing(period: period, alpha: 1 / Double(period))
        for i in items.indices {
            if i & 1023 == 0, Task.isCancelled { return result }
            let tr = trueRange(items[i], previousClose: i == 0 ? nil : items[i - 1].close)
            result[i] = average.append(tr).flatMap(finiteIndicatorValue)
        }
        return result
    }
}
