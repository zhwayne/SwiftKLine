import Foundation

/// Percentage rate of change in O(n), first available at index period.
/// A zero historical close is unavailable rather than producing an infinite ratio.
public struct ROCCalculator: IndicatorCalculator {
    public let period: Int
    public var id: SeriesKey { .roc(period: period) }

    public init(period: Int = 9) { self.period = period }

    public func calculate(for items: [any ChartItem]) -> [Double?] {
        var result = [Double?](repeating: nil, count: items.count)
        guard period > 0, period < items.count else { return result }
        for i in period..<items.count {
            if i & 1023 == 0, Task.isCancelled { return result }
            let previous = items[i - period].close
            guard previous != 0 else { continue }
            result[i] = finiteIndicatorValue(100 * (items[i].close / previous - 1))
        }
        return result
    }
}
