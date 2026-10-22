import Foundation
import Testing
@testable import SwiftKLineCore

private func oscillatorCandle(_ index: Int, _ close: Double, volume: Double = 10) -> Candle {
    Candle(timestamp: index * 60, open: close, high: close + 1, low: close - 1, close: close, volume: volume)
}

private let oscillatorFixture: [any ChartItem] = zip([10.0, 12, 11, 11, 15], [1.0, 2, 3, 4, 5])
    .enumerated().map { oscillatorCandle($0.offset, $0.element.0, volume: $0.element.1) }

private func expectNear(_ actual: Double?, _ expected: Double?, sourceLocation: SourceLocation = #_sourceLocation) {
    switch (actual, expected) {
    case (nil, nil): break
    case let (a?, b?): #expect(abs(a - b) < 1e-8 * max(1, abs(b)), sourceLocation: sourceLocation)
    default: Issue.record("Availability differs: \(String(describing: actual)) vs \(String(describing: expected))",
                          sourceLocation: sourceLocation)
    }
}

@Test func scalarOscillatorsMatchHandCalculatedExamples() {
    let cci = CCICalculator(period: 3).calculate(for: oscillatorFixture)
    let wr = WRCalculator(period: 2).calculate(for: oscillatorFixture)
    let atr = ATRCalculator(period: 2).calculate(for: oscillatorFixture)
    let obv = OBVCalculator().calculate(for: oscillatorFixture)
    let roc = ROCCalculator(period: 2).calculate(for: oscillatorFixture)
    let mfi = MFICalculator(period: 2).calculate(for: oscillatorFixture)
    let expectedCCI: [Double?] = [nil, nil, 0, -50, 100]
    let expectedWR: [Double?] = [nil, -25, -200.0 / 3, -50, -100.0 / 6]
    let expectedATR: [Double?] = [nil, 2.5, 2.25, 2.125, 3.5625]
    let expectedROC: [Double?] = [nil, nil, 10, -100.0 / 12, 400.0 / 11]
    let expectedMFI: [Double?] = [nil, nil, 2_400.0 / 57, 0, 100]
    #expect(obv == [0, 2, -1, -1, 4])
    for i in oscillatorFixture.indices {
        expectNear(cci[i], expectedCCI[i])
        expectNear(wr[i], expectedWR[i])
        expectNear(atr[i], expectedATR[i])
        expectNear(roc[i], expectedROC[i])
        expectNear(mfi[i], expectedMFI[i])
    }
}

@Test func kdjAndDMIMatchHandCalculatedExamples() {
    let kdj = KDJCalculator(period: 2).calculate(for: oscillatorFixture)
    #expect(kdj[0] == nil)
    expectNear(kdj[1]?.k, 175.0 / 3)
    expectNear(kdj[1]?.d, 475.0 / 9)
    expectNear(kdj[1]?.j, 625.0 / 9)
    expectNear(kdj[2]?.k, 50)
    expectNear(kdj[2]?.d, 1_400.0 / 27)
    expectNear(kdj[2]?.j, 1_250.0 / 27)

    let dmi = DMICalculator(diPeriod: 2, adxPeriod: 2).calculate(for: oscillatorFixture)
    #expect(dmi[0] == nil && dmi[1] == nil)
    expectNear(dmi[2]?.plusDI, 40)
    expectNear(dmi[2]?.minusDI, 20)
    #expect(dmi[2]?.adx == nil)
    expectNear(dmi[3]?.plusDI, 200.0 / 9)
    expectNear(dmi[3]?.minusDI, 100.0 / 9)
    expectNear(dmi[3]?.adx, 100.0 / 3)
    expectNear(dmi[4]?.adx, (100.0 / 3 + 1_700.0 / 19) / 2)
}

@Test func trixUsesThreeCompleteSMASeeds() {
    let items: [any ChartItem] = (1...10).map { oscillatorCandle($0, Double($0)) }
    let values = TRIXCalculator(period: 2).calculate(for: items)
    #expect(values.prefix(4).allSatisfy { $0 == nil })
    expectNear(values[4], 40)
    expectNear(values[5], 100 / 3.5)
    let periodOne = TRIXCalculator(period: 1).calculate(for: items)
    expectNear(periodOne[1], 100)
    #expect(TRIXCalculator().calculate(for: Array(items.prefix(1))) == [nil])
}

@Test func oscillatorFlatAndZeroDenominatorsAreDefined() {
    let flat: [any ChartItem] = (0..<60).map {
        Candle(timestamp: $0 * 60, open: 0, high: 0, low: 0, close: 0, volume: 0)
    }
    #expect(WRCalculator(period: 2).calculate(for: flat).allSatisfy { $0 == nil })
    #expect(ROCCalculator(period: 2).calculate(for: flat).allSatisfy { $0 == nil })
    #expect(MFICalculator(period: 2).calculate(for: flat).allSatisfy { $0 == nil })
    #expect(TRIXCalculator(period: 2).calculate(for: flat).allSatisfy { $0 == nil })
    #expect(CCICalculator(period: 2).calculate(for: flat).dropFirst().allSatisfy { $0 == 0 })
    #expect(ATRCalculator(period: 2).calculate(for: flat).dropFirst().allSatisfy { $0 == 0 })
    #expect(OBVCalculator().calculate(for: flat).allSatisfy { $0 == 0 })
    #expect(KDJCalculator(period: 2).calculate(for: flat).dropFirst().allSatisfy {
        $0 == KDJIndicatorValue(k: 50, d: 50, j: 50)
    })
    let dmi = DMICalculator(diPeriod: 2, adxPeriod: 2).calculate(for: flat)
    #expect(dmi[2] == DMIIndicatorValue(plusDI: 0, minusDI: 0, adx: nil))
    #expect(dmi[3] == DMIIndicatorValue(plusDI: 0, minusDI: 0, adx: 0))

    let tied: [any ChartItem] = [
        Candle(timestamp: 0, open: 10, high: 12, low: 8, close: 10),
        Candle(timestamp: 60, open: 10, high: 13, low: 7, close: 10)
    ]
    #expect(DMICalculator(diPeriod: 1, adxPeriod: 1).calculate(for: tied)[1]
        == DMIIndicatorValue(plusDI: 0, minusDI: 0, adx: 0))
}

private func newOscillatorCalculators(period: Int) -> [AnyIndicatorCalculator] {
    [
        KDJCalculator(period: period).eraseToAnyIndicatorCalculator(),
        CCICalculator(period: period).eraseToAnyIndicatorCalculator(),
        WRCalculator(period: period).eraseToAnyIndicatorCalculator(),
        DMICalculator(diPeriod: period, adxPeriod: period).eraseToAnyIndicatorCalculator(),
        ATRCalculator(period: period).eraseToAnyIndicatorCalculator(),
        OBVCalculator().eraseToAnyIndicatorCalculator(),
        ROCCalculator(period: period).eraseToAnyIndicatorCalculator(),
        MFICalculator(period: period).eraseToAnyIndicatorCalculator(),
        TRIXCalculator(period: period).eraseToAnyIndicatorCalculator()
    ]
}

@Test(arguments: [Int.min, -1, 0, Int.max])
func oscillatorInvalidPeriodsAndIntegerLimits(period: Int) {
    for calculator in newOscillatorCalculators(period: period) where calculator.id != .obv {
        let store = calculator.calculateStore(items: oscillatorFixture)
        if calculator.id.indicatorID == .kdj {
            #expect(store.values(for: calculator.id, as: KDJIndicatorValue.self)?.allSatisfy { $0 == nil } == true)
        } else if calculator.id.indicatorID == .dmi {
            #expect(store.values(for: calculator.id, as: DMIIndicatorValue.self)?.allSatisfy { $0 == nil } == true)
        } else {
            #expect(store.values(for: calculator.id, as: Double.self)?.allSatisfy { $0 == nil } == true)
        }
    }
    #expect(KDJCalculator(kPeriod: 0).calculate(for: oscillatorFixture).allSatisfy { $0 == nil })
    #expect(KDJCalculator(dPeriod: -1).calculate(for: oscillatorFixture).allSatisfy { $0 == nil })
    #expect(DMICalculator(diPeriod: 1, adxPeriod: 0).calculate(for: oscillatorFixture).allSatisfy { $0 == nil })
}

@Test(arguments: [1, 3, 14])
func oscillatorsMatchIndependentWindowAndEMAReferences(period: Int) {
    let items: [any ChartItem] = (0..<180).map {
        oscillatorCandle($0, 100 + sin(Double($0) * 0.7) * 20, volume: Double(($0 % 7) * 100))
    }
    let cci = CCICalculator(period: period).calculate(for: items)
    let wr = WRCalculator(period: period).calculate(for: items)
    let mfi = MFICalculator(period: period).calculate(for: items)
    let trix = TRIXCalculator(period: period).calculate(for: items)
    let kdj = KDJCalculator(period: period).calculate(for: items)
    let tp = items.map { ($0.high + $0.low + $0.close) / 3 }
    var k = 50.0, d = 50.0
    for i in items.indices where i >= period - 1 {
        let window = items[(i - period + 1)...i]
        let high = window.map(\.high).max()!
        let low = window.map(\.low).min()!
        let mean = tp[(i - period + 1)...i].reduce(0, +) / Double(period)
        let mad = tp[(i - period + 1)...i].reduce(0) { $0 + abs($1 - mean) } / Double(period)
        expectNear(cci[i], mad == 0 ? 0 : (tp[i] - mean) / (0.015 * mad))
        expectNear(wr[i], -100 * (high - items[i].close) / (high - low))
        let rsv = 100 * (items[i].close - low) / (high - low)
        k = (2 * k + rsv) / 3
        d = (2 * d + k) / 3
        expectNear(kdj[i]?.k, k)
        expectNear(kdj[i]?.d, d)
        expectNear(kdj[i]?.j, 3 * k - 2 * d)
        if i >= period {
            var p = 0.0, n = 0.0
            for j in (i - period + 1)...i {
                if tp[j] > tp[j - 1] { p += tp[j] * items[j].volume }
                if tp[j] < tp[j - 1] { n += tp[j] * items[j].volume }
            }
            expectNear(mfi[i], p + n == 0 ? nil : 100 * p / (p + n))
        }
    }
    func ema(_ source: [Double?]) -> [Double?] {
        var output = [Double?](repeating: nil, count: source.count)
        guard let first = source.firstIndex(where: { $0 != nil }), first + period <= source.count else { return output }
        let seed = first + period - 1
        output[seed] = source[first...seed].compactMap { $0 }.reduce(0, +) / Double(period)
        for i in (seed + 1)..<source.count {
            output[i] = output[i - 1]! * (1 - 2 / (Double(period) + 1))
                + source[i]! * 2 / (Double(period) + 1)
        }
        return output
    }
    let triple = ema(ema(ema(items.map { Optional($0.close) })))
    for i in 1..<items.count {
        let expected = triple[i - 1].flatMap { previous in triple[i].map { 100 * ($0 / previous - 1) } }
        expectNear(trix[i], expected)
    }
}

@Test func oscillatorDefaultWarmupsAndIdentities() {
    let items: [any ChartItem] = (0..<100).map { oscillatorCandle($0, Double($0 + 1)) }
    #expect(KDJCalculator().calculate(for: items).firstIndex { $0 != nil } == 8)
    #expect(CCICalculator().calculate(for: items).firstIndex { $0 != nil } == 19)
    #expect(WRCalculator().calculate(for: items).firstIndex { $0 != nil } == 13)
    #expect(ATRCalculator().calculate(for: items).firstIndex { $0 != nil } == 13)
    #expect(ROCCalculator().calculate(for: items).firstIndex { $0 != nil } == 9)
    #expect(MFICalculator().calculate(for: items).firstIndex { $0 != nil } == 14)
    #expect(TRIXCalculator().calculate(for: items).firstIndex { $0 != nil } == 52)
    let dmi = DMICalculator().calculate(for: items)
    #expect(dmi.firstIndex { $0 != nil } == 14)
    #expect(dmi.firstIndex { $0?.adx != nil } == 27)
    #expect(KDJCalculator().id == .kdj(period: 9, kPeriod: 3, dPeriod: 3))
    #expect(KDJCalculator(kPeriod: 2).id != KDJCalculator().id)
    #expect(KDJCalculator(dPeriod: 2).id != KDJCalculator().id)
    #expect(DMICalculator().id == .dmi(diPeriod: 14, adxPeriod: 14))
    #expect(DMICalculator(diPeriod: 2).id != DMICalculator().id)
    #expect(DMICalculator(adxPeriod: 2).id != DMICalculator().id)
    let defaults = [CCICalculator().id, WRCalculator().id, ATRCalculator().id,
        ROCCalculator().id, MFICalculator().id, TRIXCalculator().id]
    let alternate = [CCICalculator(period: 2).id, WRCalculator(period: 2).id, ATRCalculator(period: 2).id,
        ROCCalculator(period: 2).id, MFICalculator(period: 2).id, TRIXCalculator(period: 2).id]
    #expect(zip(defaults, alternate).allSatisfy { $0 != $1 })
    #expect(OBVCalculator().id == .obv)
}

@Test func mfiRecoversFromNoFlowWindowsWithoutRoundingGhosts() {
    let closes = [10.1, 10.2, 9.9, 10.1] + Array(repeating: 10.1, count: 30) + [10.2, 10.0]
    let items: [any ChartItem] = closes.enumerated().map {
        oscillatorCandle($0.offset, $0.element, volume: 0.3)
    }
    let values = MFICalculator(period: 7).calculate(for: items)
    #expect(values[10..<34].allSatisfy { $0 == nil })
    expectNear(values[34], 100)
    expectNear(values[35], 100 * 10.2 / (10.2 + 10))
}

@Test func largeMonotonicWindowsKeepTheCorrectExtremesAfterDequeCompaction() {
    let period = 4_097
    let items: [any ChartItem] = (0..<12_000).map { oscillatorCandle($0, Double($0 + 10)) }
    let wr = WRCalculator(period: period).calculate(for: items)
    let kdj = KDJCalculator(period: period, kPeriod: 1, dPeriod: 1).calculate(for: items)
    for i in [period - 1, 8_192, 11_999] {
        expectNear(wr[i], -100 / Double(period + 1))
        expectNear(kdj[i]?.k, 100 * Double(period) / Double(period + 1))
        expectNear(kdj[i]?.j, kdj[i]?.k)
    }
}

@Test func allOscillatorUpdatesMatchRebuildAfterRevisionsAndInsertions() async {
    let calculators = newOscillatorCalculators(period: 3)
    var items: [any ChartItem] = (0..<80).map { oscillatorCandle($0, 100 + sin(Double($0)) * 10) }
    var previous = await IndicatorEngine.calculate(items: items, calculators: calculators)
    for index in [79, 20, 0, 80, 12] {
        if index == 12 { items.insert(oscillatorCandle(12, 107), at: index) }
        if index < items.count { items[index] = oscillatorCandle(index, 125) }
        else { items.append(oscillatorCandle(index, 98)) }
        let updated = await IndicatorEngine.calculate(items: items, calculators: calculators,
            previous: previous, invalidatedFrom: index)
        let rebuilt = await IndicatorEngine.calculate(items: items, calculators: calculators)
        for calculator in calculators {
            switch calculator.id.indicatorID {
            case .kdj:
                #expect(updated.values(for: calculator.id, as: KDJIndicatorValue.self)
                    == rebuilt.values(for: calculator.id, as: KDJIndicatorValue.self))
            case .dmi:
                #expect(updated.values(for: calculator.id, as: DMIIndicatorValue.self)
                    == rebuilt.values(for: calculator.id, as: DMIIndicatorValue.self))
            default:
                #expect(updated.values(for: calculator.id, as: Double.self)
                    == rebuilt.values(for: calculator.id, as: Double.self))
            }
        }
        previous = updated
    }
    items.insert(oscillatorCandle(-1, 96), at: 0)
    for calculator in calculators {
        let store = calculator.calculateStore(items: [])
        if calculator.id.indicatorID == .kdj {
            #expect(store.values(for: calculator.id, as: KDJIndicatorValue.self)?.isEmpty == true)
        } else if calculator.id.indicatorID == .dmi {
            #expect(store.values(for: calculator.id, as: DMIIndicatorValue.self)?.isEmpty == true)
        } else {
            #expect(store.values(for: calculator.id, as: Double.self)?.isEmpty == true)
        }
    }
    let inserted = await IndicatorEngine.calculate(items: items, calculators: calculators, previous: previous, invalidatedFrom: 0)
    #expect(inserted.values(for: .obv, as: Double.self) == ContiguousArray(OBVCalculator().calculate(for: items)))
}
