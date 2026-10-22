import Foundation

/// Percentage change of a triple EMA in O(n), with no signal line.
/// Each EMA is seeded by its own first complete SMA window. The first TRIX value is at
/// 3 × (period - 1) + 1 (zero-based). A zero previous triple EMA yields nil.
public struct TRIXCalculator: IndicatorCalculator {
    public let period: Int
    public var id: SeriesKey { .trix(period: period) }

    public init(period: Int = 18) { self.period = period }

    public func calculate(for items: [any ChartItem]) -> [Double?] {
        var result = [Double?](repeating: nil, count: items.count)
        guard period > 0, items.count >= 2, period - 1 <= (items.count - 2) / 3 else { return result }
        let alpha = 2 / (Double(period) + 1)
        var first = SeededSmoothing(period: period, alpha: alpha)
        var second = SeededSmoothing(period: period, alpha: alpha)
        var third = SeededSmoothing(period: period, alpha: alpha)
        var previous: Double?
        for i in items.indices {
            if i & 1023 == 0, Task.isCancelled { return result }
            guard let e1 = first.append(items[i].close),
                  let e2 = second.append(e1),
                  let e3 = third.append(e2) else { continue }
            if let previous, previous != 0 {
                result[i] = finiteIndicatorValue(100 * (e3 / previous - 1))
            }
            previous = e3
        }
        return result
    }
}
