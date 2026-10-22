//
//  CoreTests.swift
//  SwiftKLineCoreTests
//
//  Created by zhwayne on 2026/10/21.
//

import Foundation
import Testing
@testable import SwiftKLineCore

private func candle(_ timestamp: Int, _ close: Double) -> Candle {
    Candle(timestamp: timestamp, open: close - 0.5, high: close + 2, low: close - 2,
           close: close, volume: close * 10)
}

private let sample: [any ChartItem] = (0..<240).map {
    candle($0 * 60, 100 + sin(Double($0) * 0.7) * 12 + Double($0 % 13))
}

private func near(_ lhs: Double?, _ rhs: Double?, tolerance: Double = 1e-8) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil): true
    case let (a?, b?): abs(a - b) <= tolerance * max(1, abs(b))
    default: false
    }
}

@Test func candleRoundTripsAndUsesTimestampIdentity() throws {
    let original = candle(123, 42)
    let restored = try JSONDecoder().decode(Candle.self, from: JSONEncoder().encode(original))
    #expect(original == restored)
    #expect(restored.id == 123)
}

@Test func mergeNormalizesDuplicatesInBothBatches() {
    var merger = DataMerger()
    let current = [candle(120, 2), candle(60, 1), candle(120, 3)]
    let patch = [candle(180, 4), candle(60, 5), candle(180, 6)]
    let initial = merger.merge(current: [], patch: current)
    #expect(initial.map(\.close) == [1, 3])
    let result = merger.merge(current: current, patch: patch)
    #expect(result.map(\.timestamp) == [60, 120, 180])
    #expect(result.map(\.close) == [5, 3, 6])
}

@Test func gapsDoNotChangeCandleIdentity() {
    var merger = DataMerger()
    var items = merger.merge(current: [], patch: [candle(60, 1), candle(180, 3)])
    let inserted = merger.applyLiveTick(candle(120, 2), to: &items)
    #expect(inserted == .inserted(index: 1, appendedToTail: false))
    #expect(items.map(\.timestamp) == [60, 120, 180])
    #expect(merger.applyLiveTick(candle(125, 4), to: &items) == .inserted(index: 2, appendedToTail: false))
}

@Test func explicitBucketsWorkBeforeEpochAndAtIntegerLimits() {
    var merger = DataMerger(period: .oneMinute)
    var items = merger.merge(current: [], patch: [candle(-120, 1), candle(-60, 2), candle(0, 3)])
    #expect(merger.applyLiveTick(candle(-1, 4), to: &items) == .replaced(index: 1))
    #expect(items.map(\.close) == [1, 4, 3])
    let extremes = merger.merge(current: [], patch: [candle(Int.max, 1), candle(Int.min, 2)])
    #expect(extremes.map(\.timestamp) == [Int.min, Int.max])
}

@Test func liveBinarySearchMatchesSortedReference() {
    var merger = DataMerger()
    var items: [any ChartItem] = []
    var reference: [Int: Double] = [:]
    for i in 0..<2000 {
        let timestamp = (i * 317) % 997
        _ = merger.applyLiveTick(candle(timestamp, Double(i)), to: &items)
        reference[timestamp] = Double(i)
    }
    #expect(items.map(\.timestamp) == reference.keys.sorted())
    #expect(items.map(\.close) == reference.keys.sorted().map { reference[$0]! })
}

@Test(arguments: [1, 2, 5, 20, 100, 240])
func rollingIndicatorsMatchWindowReference(period: Int) {
    let wma = WMACalculator(period: period).calculate(for: sample)
    let ma = MACalculator(period: period).calculate(for: sample)
    let boll = BOLLCalculator(period: period).calculate(for: sample)
    let vwma = VWMACalculator(period: period).calculate(for: sample)
    let donchian = DonchianCalculator(period: period).calculate(for: sample)
    for i in sample.indices {
        if i < period - 1 {
            #expect(wma[i] == nil && ma[i] == nil && boll[i] == nil)
            #expect(vwma[i] == nil && donchian[i] == nil)
            continue
        }
        let items = sample[(i - period + 1)...i]
        let window = items.map(\.close)
        let mean = window.reduce(0, +) / Double(period)
        let variance = window.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(period)
        let weighted = window.enumerated().reduce(0) { $0 + $1.element * Double($1.offset + 1) }
        let volume = items.reduce(0) { $0 + $1.volume }
        let priceVolume = items.reduce(0) { $0 + $1.close * $1.volume }
        #expect(near(ma[i], mean))
        #expect(near(wma[i], weighted / (Double(period) * (Double(period) + 1) / 2)))
        #expect(near(boll[i]?.middle, mean))
        #expect(near(boll[i]?.upper, mean + 2 * sqrt(variance)))
        #expect(near(boll[i]?.lower, mean - 2 * sqrt(variance)))
        #expect(near(vwma[i], priceVolume / volume))
        #expect(near(donchian[i]?.upper, items.map(\.high).max()))
        #expect(near(donchian[i]?.lower, items.map(\.low).min()))
        #expect(near(donchian[i]?.middle,
                    ((items.map(\.high).max() ?? 0) + (items.map(\.low).min() ?? 0)) / 2))
    }
}

@Test func bbiMatchesEqualWeightMovingAverageReference() {
    let periods = [3, 6, 12, 24]
    let actual = BBICalculator(periods: periods).calculate(for: sample)
    let averages = periods.map { MACalculator(period: $0).calculate(for: sample) }
    let first = (periods.max() ?? 1) - 1
    for i in sample.indices {
        if i < first { #expect(actual[i] == nil); continue }
        let expected = averages.reduce(0.0) { $0 + ($1[i] ?? 0) } / Double(periods.count)
        #expect(near(actual[i], expected))
    }
    #expect(BBICalculator(periods: [24, 12, 6, 3]).id == .bbi)
}

@Test(arguments: [-1, 0, Int.max])
func invalidPeriodsDoNotTrap(period: Int) {
    let calculators: [any IndicatorCalculator] = [MACalculator(period: period), WMACalculator(period: period),
        BOLLCalculator(period: period), RSICalculator(period: period), VWMACalculator(period: period),
        DonchianCalculator(period: period), BBICalculator(periods: [period]),
        SuperTrendCalculator(period: period),
        IchimokuCalculator(tenkanPeriod: period, kijunPeriod: period,
                           senkouBPeriod: period, displacement: 0)]
    for calculator in calculators {
        let output = calculator.eraseToAnyIndicatorCalculator().calculateStore(items: sample)
        if calculator.id.indicatorID == .boll {
            #expect(output.values(for: calculator.id, as: BOLLIndicatorValue.self)?.allSatisfy { $0 == nil } == true)
        } else if calculator.id.indicatorID == .donchian {
            #expect(output.values(for: calculator.id, as: BandIndicatorValue.self)?.allSatisfy { $0 == nil } == true)
        } else if calculator.id.indicatorID == .superTrend {
            #expect(output.values(for: calculator.id, as: SuperTrendIndicatorValue.self)?.allSatisfy { $0 == nil } == true)
        } else if calculator.id.indicatorID == .ichimoku {
            #expect(output.values(for: calculator.id, as: IchimokuIndicatorValue.self)?.allSatisfy {
                $0?.tenkan == nil && $0?.kijun == nil && $0?.spanA == nil && $0?.spanB == nil
            } == true)
        } else {
            #expect(output.values(for: calculator.id, as: Double.self)?.allSatisfy { $0 == nil } == true)
        }
    }
}

@Test func vwmaRejectsZeroVolumeWindowsAndNewParametersChangeIdentity() {
    let items: [any ChartItem] = (0..<6).map {
        Candle(timestamp: $0 * 60, open: 10, high: 11, low: 9, close: 10, volume: 0)
    }
    let values = VWMACalculator(period: 2).calculate(for: items)
    #expect(values.allSatisfy { $0 == nil })

    #expect(VWMACalculator(period: 20).id == .vwma(period: 20))
    #expect(VWMACalculator(period: 20).id != .vwma(period: 10))
    #expect(DonchianCalculator(period: 20).id == .donchian(period: 20))
    #expect(DonchianCalculator(period: 20).id != .donchian(period: 10))
}

/// A straightforward SuperTrend reference that keeps the band and trend state outside the production type.
private func superTrendReference(
    _ items: [any ChartItem],
    period: Int,
    multiplier: Double
) -> [(value: Double, isUp: Bool)?] {
    var result = [(value: Double, isUp: Bool)?](repeating: nil, count: items.count)
    guard period > 0, items.count >= period else { return result }

    var averageTrueRange: Double?
    var trueRangeSum = 0.0
    var finalUpper = 0.0
    var finalLower = 0.0
    var isUp = false
    for i in items.indices {
        let item = items[i]
        let trueRange = i == 0 ? item.high - item.low : max(
            item.high - item.low,
            abs(item.high - items[i - 1].close),
            abs(item.low - items[i - 1].close)
        )
        if i < period - 1 {
            trueRangeSum += trueRange
            continue
        }
        if i == period - 1 {
            averageTrueRange = (trueRangeSum + trueRange) / Double(period)
        } else {
            averageTrueRange = (averageTrueRange! * Double(period - 1) + trueRange) / Double(period)
        }

        let atr = averageTrueRange!
        let midpoint = (item.high + item.low) / 2
        let basicUpper = midpoint + multiplier * atr
        let basicLower = midpoint - multiplier * atr
        if i == period - 1 {
            finalUpper = basicUpper
            finalLower = basicLower
        } else {
            let previousUpper = finalUpper
            let previousLower = finalLower
            finalUpper = (basicUpper < previousUpper || items[i - 1].close > previousUpper)
                ? basicUpper : previousUpper
            finalLower = (basicLower > previousLower || items[i - 1].close < previousLower)
                ? basicLower : previousLower
            isUp = isUp ? item.close >= finalLower : item.close > finalUpper
        }
        result[i] = (isUp ? finalLower : finalUpper, isUp)
    }
    return result
}

@Test(arguments: [(1, 1.0), (5, 3.0), (10, 3.0)])
func superTrendMatchesReference(parameters: (Int, Double)) {
    let actual = SuperTrendCalculator(period: parameters.0, multiplier: parameters.1).calculate(for: sample)
    let expected = superTrendReference(sample, period: parameters.0, multiplier: parameters.1)
    for i in sample.indices {
        #expect(near(actual[i]?.value, expected[i]?.value))
        #expect(actual[i]?.isUp == expected[i]?.isUp)
    }
}

@Test func superTrendParametersArePartOfSeriesIdentity() {
    #expect(SuperTrendCalculator().id == .superTrend(period: 10, multiplier: 3))
    #expect(SuperTrendCalculator(period: 7).id != SuperTrendCalculator().id)
    #expect(SuperTrendCalculator(multiplier: 2).id != SuperTrendCalculator().id)
}

@Test func superTrendRejectsNegativeAndNonFiniteMultipliers() {
    let invalidMultipliers: [Double] = [-1, -.infinity, .infinity, .nan]
    for multiplier in invalidMultipliers {
        let values = SuperTrendCalculator(period: 3, multiplier: multiplier).calculate(for: sample)
        #expect(values.allSatisfy { $0 == nil })
    }

    let zeroValues = SuperTrendCalculator(period: 3, multiplier: 0).calculate(for: sample)
    #expect(zeroValues[2] != nil)
}

@Test func superTrendSeedsTheFirstCalculableCandleInADowntrend() throws {
    let period = 5
    let values = SuperTrendCalculator(period: period, multiplier: 3).calculate(for: sample)
    let first = try #require(values[period - 1])

    #expect(first.isUp == false)
    #expect(near(first.value, superTrendReference(
        sample, period: period, multiplier: 3
    )[period - 1]?.value))
}

/// A window-scanning midpoint reference used to verify the monotonic production implementation.
private func rollingMidpoint(_ items: [any ChartItem], at index: Int, period: Int) -> Double? {
    guard period > 0, index >= period - 1 else { return nil }
    var high = -Double.infinity
    var low = Double.infinity
    for i in (index - period + 1)...index {
        high = max(high, items[i].high)
        low = min(low, items[i].low)
    }
    return (high + low) / 2
}

@Test(arguments: [(9, 26, 52, 26), (1, 1, 1, 0), (5, 10, 20, 3)])
func ichimokuMatchesDisplacedReference(parameters: (Int, Int, Int, Int)) {
    let (tenkanPeriod, kijunPeriod, senkouBPeriod, displacement) = parameters
    let actual = IchimokuCalculator(
        tenkanPeriod: tenkanPeriod,
        kijunPeriod: kijunPeriod,
        senkouBPeriod: senkouBPeriod,
        displacement: displacement
    ).calculate(for: sample)

    var rawTenkan = [Double?](repeating: nil, count: sample.count)
    var rawKijun = [Double?](repeating: nil, count: sample.count)
    var rawSpanA = [Double?](repeating: nil, count: sample.count)
    var rawSpanB = [Double?](repeating: nil, count: sample.count)
    for i in sample.indices {
        rawTenkan[i] = rollingMidpoint(sample, at: i, period: tenkanPeriod)
        rawKijun[i] = rollingMidpoint(sample, at: i, period: kijunPeriod)
        rawSpanB[i] = rollingMidpoint(sample, at: i, period: senkouBPeriod)
        if let tenkan = rawTenkan[i], let kijun = rawKijun[i] {
            rawSpanA[i] = (tenkan + kijun) / 2
        }
    }

    for i in sample.indices {
        let source = i - displacement
        let spanA = source >= 0 ? rawSpanA[source] : nil
        let spanB = source >= 0 ? rawSpanB[source] : nil
        let chikouIndex = i + displacement
        let chikou = chikouIndex < sample.count ? sample[chikouIndex].close : nil
        #expect(near(actual[i]?.tenkan, rawTenkan[i]))
        #expect(near(actual[i]?.kijun, rawKijun[i]))
        #expect(near(actual[i]?.spanA, spanA))
        #expect(near(actual[i]?.spanB, spanB))
        #expect(near(actual[i]?.chikou, chikou))
    }
}

@Test func ichimokuParametersArePartOfSeriesIdentity() {
    let standard = IchimokuCalculator()
    #expect(standard.id == .ichimoku(
        tenkanPeriod: 9, kijunPeriod: 26, senkouBPeriod: 52, displacement: 26
    ))
    #expect(IchimokuCalculator(tenkanPeriod: 7).id != standard.id)
    #expect(IchimokuCalculator(kijunPeriod: 20).id != standard.id)
    #expect(IchimokuCalculator(senkouBPeriod: 40).id != standard.id)
    #expect(IchimokuCalculator(displacement: 20).id != standard.id)
}

@Test func rollingDequePreservesOrderAcrossFrontCompaction() {
    var deque = RollingDeque<Int>()
    deque.reserveCapacity(4_096)
    for value in 0..<4_096 { deque.append(value) }

    for expected in 0..<3_500 {
        #expect(deque.first == expected)
        #expect(deque.removeFirst() == expected)
    }
    #expect(deque.first == 3_500)
    #expect(deque.last == 4_095)

    for expected in stride(from: 4_095, through: 3_500, by: -1) {
        #expect(deque.removeLast() == expected)
    }
    #expect(deque.first == nil)
    #expect(deque.last == nil)
}

@Test func bollIsStableForLargePricesWithSmallSpreads() {
    let items = (0..<100).map { candle($0, 1e12 + Double($0 % 3) * 0.25) }
    let values = BOLLCalculator(period: 20).calculate(for: items)
    for i in 19..<items.count {
        let window = items[(i - 19)...i].map(\.close)
        let mean = window.reduce(0, +) / 20
        let deviation = sqrt(window.reduce(0) { $0 + pow($1 - mean, 2) } / 20)
        #expect(abs((values[i]!.upper - values[i]!.middle) - 2 * deviation) < 0.003)
    }
}

@Test(arguments: [1, 5, 20])
func suffixUpdatesMatchFullRecalculation(period: Int) async {
    let calculators: [AnyIndicatorCalculator] = [MACalculator(period: period).eraseToAnyIndicatorCalculator(),
        EMACalculator(period: period).eraseToAnyIndicatorCalculator(), WMACalculator(period: period).eraseToAnyIndicatorCalculator(),
        BOLLCalculator(period: period).eraseToAnyIndicatorCalculator(), VOLCalculator().eraseToAnyIndicatorCalculator(),
        RSICalculator(period: period).eraseToAnyIndicatorCalculator(), MACDCalculator().eraseToAnyIndicatorCalculator(),
        SARCalculator().eraseToAnyIndicatorCalculator(), VWMACalculator(period: period).eraseToAnyIndicatorCalculator(),
        DonchianCalculator(period: period).eraseToAnyIndicatorCalculator(),
        BBICalculator(periods: [period, period + 1, period + 2, period + 3]).eraseToAnyIndicatorCalculator(),
        SuperTrendCalculator(period: period, multiplier: 3).eraseToAnyIndicatorCalculator(),
        IchimokuCalculator(tenkanPeriod: period, kijunPeriod: period + 1,
                           senkouBPeriod: period + 2,
                           displacement: min(period, 3)).eraseToAnyIndicatorCalculator()]
    var items = Array(sample.prefix(30))
    var previous = await IndicatorEngine.calculate(items: items, calculators: calculators)
    for step in 0..<40 {
        let index = step % 4 == 0 ? 4 : items.count - 1
        items[index] = candle(items[index].timestamp, 110 + Double(step))
        if step % 2 == 0 { items.append(candle(items.count * 60, Double(step) + 100)) }
        let updated = await IndicatorEngine.calculate(items: items, calculators: calculators, previous: previous, invalidatedFrom: index)
        let full = await IndicatorEngine.calculate(items: items, calculators: calculators)
        for calculator in calculators {
            if let expected = full.values(for: calculator.id, as: Double.self),
               let actual = updated.values(for: calculator.id, as: Double.self) {
                #expect(zip(actual, expected).allSatisfy { near($0, $1) })
            } else if let expected = full.values(for: calculator.id, as: BOLLIndicatorValue.self),
                      let actual = updated.values(for: calculator.id, as: BOLLIndicatorValue.self) {
                #expect(zip(actual, expected).allSatisfy { near($0?.middle, $1?.middle) && near($0?.upper, $1?.upper) })
            } else if let expected = full.values(for: calculator.id, as: BandIndicatorValue.self),
                      let actual = updated.values(for: calculator.id, as: BandIndicatorValue.self) {
                #expect(zip(actual, expected).allSatisfy {
                    near($0?.middle, $1?.middle) && near($0?.upper, $1?.upper) && near($0?.lower, $1?.lower)
                })
            } else if let expected = full.values(for: calculator.id, as: SuperTrendIndicatorValue.self),
                      let actual = updated.values(for: calculator.id, as: SuperTrendIndicatorValue.self) {
                #expect(zip(actual, expected).allSatisfy {
                    near($0?.value, $1?.value) && $0?.isUp == $1?.isUp
                })
            } else if let expected = full.values(for: calculator.id, as: IchimokuIndicatorValue.self),
                      let actual = updated.values(for: calculator.id, as: IchimokuIndicatorValue.self) {
                #expect(zip(actual, expected).allSatisfy {
                    near($0?.tenkan, $1?.tenkan) && near($0?.kijun, $1?.kijun)
                        && near($0?.spanA, $1?.spanA) && near($0?.spanB, $1?.spanB)
                        && near($0?.chikou, $1?.chikou)
                })
            } else {
                #expect(updated.values(for: calculator.id, as: MACDIndicatorValue.self) == full.values(for: calculator.id, as: MACDIndicatorValue.self))
            }
        }
        previous = updated
    }
}

private struct ConstantCalculator: IndicatorCalculator {
    let id: SeriesKey = .vol
    let value: Double
    let extra: Int
    func calculate(for items: [any ChartItem]) -> [Double?] { Array(repeating: value, count: max(0, items.count + extra)) }
}

@Test func engineAlignsPluginOutputsAndResolvesDuplicateKeysInOrder() async {
    let calculators = [ConstantCalculator(value: 1, extra: 100).eraseToAnyIndicatorCalculator(),
                       ConstantCalculator(value: 2, extra: -2).eraseToAnyIndicatorCalculator()]
    let store = await IndicatorEngine.calculate(items: Array(sample.prefix(3)), calculators: calculators)
    #expect(store.values(for: .vol, as: Double.self) == [2, nil, nil])
    #expect(store.values(for: .vol, as: String.self) == nil)
}

/// Lock-protected instrumentation only; product types retain compiler-checked Sendable conformance.
private final class ReadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0
    var count: Int { lock.withLock { storage } }
    func increment() { lock.withLock { storage += 1 } }
}

private struct CountedItem: ChartItem {
    let timestamp: Int
    let counter: ReadCounter
    var close: Double { counter.increment(); return Double(timestamp % 100) }
    var open: Double { 0 }; var high: Double { 100 }; var low: Double { 0 }
    var volume: Double { 0 }; var value: Double { 0 }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.timestamp == rhs.timestamp }
}

@Test func rollingCalculationReadsGrowLinearly() {
    let counter = ReadCounter()
    let items: [any ChartItem] = (0..<4000).map { CountedItem(timestamp: $0, counter: counter) }
    _ = WMACalculator(period: 400).calculate(for: items)
    _ = BOLLCalculator(period: 400).calculate(for: items)
    #expect(counter.count < items.count * 8)
    let before = counter.count
    let calculator = WMACalculator(period: 400)
    var values = [Double?](repeating: 0, count: items.count)
    calculator.update(for: items, values: &values, from: items.count - 1)
    #expect(counter.count - before == 400)
}

@Test(arguments: [(12, 26, 9), (1, 1, 1), (40, 5, 3)])
func macdMatchesIndependentMultiArrayReference(periods: (Int, Int, Int)) {
    let (short, long, signalPeriod) = periods
    let fast = EMACalculator(period: short).calculate(for: sample)
    let slow = EMACalculator(period: long).calculate(for: sample)
    let dif = zip(fast, slow).map { $0! - $1! }
    let first = long - 1 + signalPeriod - 1
    var signal = dif[(long - 1)...first].reduce(0, +) / Double(signalPeriod)
    let actual = MACDCalculator(shortPeriod: short, longPeriod: long, signalPeriod: signalPeriod).calculate(for: sample)
    for i in sample.indices {
        if i < first { #expect(actual[i] == nil); continue }
        if i > first { signal += (dif[i] - signal) * 2 / (Double(signalPeriod) + 1) }
        #expect(near(actual[i]?.macd, dif[i]))
        #expect(near(actual[i]?.signal, signal))
        #expect(near(actual[i]?.histogram, 2 * (dif[i] - signal)))
    }
}

@Test func sarParametersArePartOfSeriesIdentity() {
    #expect(SARCalculator().id == .sar)
    #expect(SARCalculator(afStart: 0.03).id != SARCalculator().id)
}
