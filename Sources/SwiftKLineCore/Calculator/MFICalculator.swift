import Foundation

/// Money flow index in O(n), first available at index period.
/// Uses typical-price direction and volume. No negative flow yields 100, no positive flow yields 0,
/// and a window with neither positive nor negative flow is unavailable (nil).
public struct MFICalculator: IndicatorCalculator {
    public let period: Int
    public var id: SeriesKey { .mfi(period: period) }

    public init(period: Int = 14) { self.period = period }

    public func calculate(for items: [any ChartItem]) -> [Double?] {
        var result = [Double?](repeating: nil, count: items.count)
        guard period > 0, period < items.count else { return result }
        var flows = RollingDeque<(positive: Double, negative: Double)>()
        var positive = 0.0, negative = 0.0
        var positiveCount = 0, negativeCount = 0
        var previous = items[0].high / 3 + items[0].low / 3 + items[0].close / 3
        for i in 1..<items.count {
            if i & 1023 == 0, Task.isCancelled { return result }
            let item = items[i]
            let typical = item.high / 3 + item.low / 3 + item.close / 3
            let flow = typical * item.volume
            let entry = (positive: typical > previous ? flow : 0, negative: typical < previous ? flow : 0)
            previous = typical
            flows.append(entry)
            positive += entry.positive
            negative += entry.negative
            if entry.positive != 0 { positiveCount += 1 }
            if entry.negative != 0 { negativeCount += 1 }
            if i > period, let removed = flows.removeFirst() {
                positive -= removed.positive
                negative -= removed.negative
                if removed.positive != 0 { positiveCount -= 1 }
                if removed.negative != 0 { negativeCount -= 1 }
            }
            // Counts make empty/one-sided windows exact despite rolling subtraction round-off.
            if positiveCount == 0 { positive = 0 }
            if negativeCount == 0 { negative = 0 }
            guard i >= period else { continue }
            // Rebase once per window to bound accumulated round-off, retaining O(n) total work.
            if (i - period) % period == 0 {
                positive = 0; negative = 0
                var prior = items[i - period].high / 3 + items[i - period].low / 3 + items[i - period].close / 3
                for j in (i - period + 1)...i {
                    if j & 1023 == 0, Task.isCancelled { return result }
                    let value = items[j]
                    let price = value.high / 3 + value.low / 3 + value.close / 3
                    if price > prior { positive += price * value.volume }
                    else if price < prior { negative += price * value.volume }
                    prior = price
                }
            }
            guard positive > 0 || negative > 0 else { continue }
            result[i] = finiteIndicatorValue(100 * positive / (positive + negative))
        }
        return result
    }
}
