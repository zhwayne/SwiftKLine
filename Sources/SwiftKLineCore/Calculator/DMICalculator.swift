import Foundation

/// One directional-movement sample. ADX remains nil during its additional smoothing warm-up.
public struct DMIIndicatorValue: Equatable, Sendable {
    public let plusDI: Double
    public let minusDI: Double
    public let adx: Double?

    public init(plusDI: Double, minusDI: Double, adx: Double?) {
        self.plusDI = plusDI
        self.minusDI = minusDI
        self.adx = adx
    }
}

/// Computes Wilder +DI, -DI and ADX in O(n), without ADXR.
/// DI starts at diPeriod and ADX at diPeriod + adxPeriod - 1 (zero-based).
/// Tied directional moves, zero true range and zero DI sum yield zero contributions.
public struct DMICalculator: IndicatorCalculator {
    public let diPeriod: Int
    public let adxPeriod: Int
    public var id: SeriesKey { .dmi(diPeriod: diPeriod, adxPeriod: adxPeriod) }

    public init(diPeriod: Int = 14, adxPeriod: Int = 14) {
        self.diPeriod = diPeriod
        self.adxPeriod = adxPeriod
    }

    public func calculate(for items: [any ChartItem]) -> [DMIIndicatorValue?] {
        var result = [DMIIndicatorValue?](repeating: nil, count: items.count)
        guard diPeriod > 0, adxPeriod > 0, diPeriod < items.count else { return result }
        var tr = SeededSmoothing(period: diPeriod, alpha: 1 / Double(diPeriod))
        var plus = SeededSmoothing(period: diPeriod, alpha: 1 / Double(diPeriod))
        var minus = SeededSmoothing(period: diPeriod, alpha: 1 / Double(diPeriod))
        var adx = SeededSmoothing(period: adxPeriod, alpha: 1 / Double(adxPeriod))
        for i in 1..<items.count {
            if i & 1023 == 0, Task.isCancelled { return result }
            let up = items[i].high - items[i - 1].high
            let down = items[i - 1].low - items[i].low
            let smoothedTR = tr.append(trueRange(items[i], previousClose: items[i - 1].close))
            let smoothedPlus = plus.append(up > down && up > 0 ? up : 0)
            let smoothedMinus = minus.append(down > up && down > 0 ? down : 0)
            guard let t = smoothedTR, let p = smoothedPlus, let m = smoothedMinus else { continue }
            let plusDI = t == 0 ? 0 : 100 * p / t
            let minusDI = t == 0 ? 0 : 100 * m / t
            let sum = plusDI + minusDI
            let dx = sum == 0 ? 0 : 100 * abs(plusDI - minusDI) / sum
            let strength = adx.append(dx).flatMap(finiteIndicatorValue)
            guard plusDI.isFinite, minusDI.isFinite else { continue }
            result[i] = DMIIndicatorValue(plusDI: plusDI, minusDI: minusDI, adx: strength)
        }
        return result
    }
}
