import Foundation

/// Computes classic typical-price CCI with constant 0.015.
/// The first output is at period - 1. Zero mean deviation yields 0.
/// Exact window mean absolute deviation costs O(n × period); updates rebuild all outputs.
public struct CCICalculator: IndicatorCalculator {
    public let period: Int
    public var id: SeriesKey { .cci(period: period) }

    public init(period: Int = 20) { self.period = period }

    public func calculate(for items: [any ChartItem]) -> [Double?] {
        var result = [Double?](repeating: nil, count: items.count)
        guard period > 0, period <= items.count else { return result }
        var prices = [Double]()
        prices.reserveCapacity(items.count)
        for i in items.indices {
            if i & 1023 == 0, Task.isCancelled { return result }
            let item = items[i]
            prices.append(item.high / 3 + item.low / 3 + item.close / 3)
            guard i >= period - 1 else { continue }
            let first = i - (period - 1)
            var mean = 0.0
            for j in first...i {
                if j & 1023 == 0, Task.isCancelled { return result }
                mean += (prices[j] - mean) / Double(j - first + 1)
            }
            var deviation = 0.0
            for j in first...i {
                if j & 1023 == 0, Task.isCancelled { return result }
                deviation += abs(prices[j] - mean) / Double(period)
            }
            result[i] = deviation == 0 ? 0 : finiteIndicatorValue((prices[i] - mean) / (0.015 * deviation))
        }
        return result
    }
}
