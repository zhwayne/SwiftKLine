import Foundation

/// Monotonic rolling extrema; each sample enters and leaves each deque at most once.
struct RollingExtremes {
    private var highs = RollingDeque<(index: Int, value: Double)>()
    private var lows = RollingDeque<(index: Int, value: Double)>()

    mutating func append(index: Int, high: Double, low: Double, period: Int) {
        let lower = index - (period - 1)
        while let first = highs.first, first.index < lower { highs.removeFirst() }
        while let first = lows.first, first.index < lower { lows.removeFirst() }
        while let last = highs.last, last.value <= high { highs.removeLast() }
        while let last = lows.last, last.value >= low { lows.removeLast() }
        highs.append((index, high))
        lows.append((index, low))
    }

    var range: (high: Double, low: Double)? {
        guard let high = highs.first?.value, let low = lows.first?.value else { return nil }
        return (high, low)
    }
}

/// Seeds with a complete-window arithmetic mean, then applies EMA or Wilder smoothing.
struct SeededSmoothing {
    let period: Int
    let alpha: Double
    private var count = 0
    private var mean = 0.0

    init(period: Int, alpha: Double) {
        self.period = period
        self.alpha = alpha
    }

    mutating func append(_ value: Double) -> Double? {
        if count < period {
            count += 1
            mean += (value - mean) / Double(count)
            return count == period ? mean : nil
        }
        mean += alpha * (value - mean)
        return mean
    }
}

func finiteIndicatorValue(_ value: Double) -> Double? {
    value.isFinite ? value : nil
}

func trueRange(_ item: any ChartItem, previousClose: Double?) -> Double {
    guard let previousClose else { return item.high - item.low }
    return max(item.high - item.low, abs(item.high - previousClose), abs(item.low - previousClose))
}
