//
//  KLineTests.swift
//  SwiftKLineTests
//
//  Created by zhwayne on 2026/04/27.
//

#if canImport(UIKit)
import Testing
@testable import SwiftKLineUI
@testable import SwiftKLineCore

private struct TestChartItem: ChartItem {
    let open: Double
    let close: Double
    let high: Double
    let low: Double
    let volume: Double
    let value: Double
    let timestamp: Int

    init(timestamp: Int, close: Double) {
        self.open = close
        self.close = close
        self.high = close
        self.low = close
        self.volume = 0
        self.value = 0
        self.timestamp = timestamp
    }
}

@Test func dataMergerSortsAndOverwritesByTimestamp() {
    var merger = DataMerger(period: .oneMinute)
    let current: [any ChartItem] = [
        TestChartItem(timestamp: 120, close: 2),
        TestChartItem(timestamp: 60, close: 1),
    ]
    let patch: [any ChartItem] = [
        TestChartItem(timestamp: 120, close: 20),
        TestChartItem(timestamp: 180, close: 3),
    ]

    let merged = merger.merge(current: current, patch: patch)

    #expect(merged.map(\.timestamp) == [60, 120, 180])
    #expect(merged.map(\.close) == [1, 20, 3])
}

@Test func dataMergerReplacesLiveTickInExistingBucket() {
    var merger = DataMerger(period: .oneMinute)
    var items: [any ChartItem] = [
        TestChartItem(timestamp: 60, close: 1),
        TestChartItem(timestamp: 120, close: 2),
        TestChartItem(timestamp: 180, close: 3),
    ]

    let result = merger.applyLiveTick(TestChartItem(timestamp: 125, close: 22), to: &items)

    #expect(result == .replaced(index: 1))
    #expect(items.map(\.timestamp) == [60, 125, 180])
    #expect(items.map(\.close) == [1, 22, 3])
}

@Test func dataMergerInsertsLiveTickAtSortedBucketPosition() {
    var merger = DataMerger(period: .oneMinute)
    var items: [any ChartItem] = [
        TestChartItem(timestamp: 60, close: 1),
        TestChartItem(timestamp: 180, close: 3),
    ]

    let result = merger.applyLiveTick(TestChartItem(timestamp: 120, close: 2), to: &items)

    #expect(result == .inserted(index: 1, appendedToTail: false))
    #expect(items.map(\.timestamp) == [60, 120, 180])
}

@Test func dataMergerReportsTailAppend() {
    var merger = DataMerger(period: .oneMinute)
    var items: [any ChartItem] = [
        TestChartItem(timestamp: 60, close: 1),
        TestChartItem(timestamp: 120, close: 2),
    ]

    let result = merger.applyLiveTick(TestChartItem(timestamp: 180, close: 3), to: &items)

    #expect(result == .inserted(index: 2, appendedToTail: true))
    #expect(items.map(\.timestamp) == [60, 120, 180])
}

@Test func maCalculatorCalculatesMovingAverage() {
    let items: [any ChartItem] = [
        TestChartItem(timestamp: 1, close: 1),
        TestChartItem(timestamp: 2, close: 2),
        TestChartItem(timestamp: 3, close: 3),
        TestChartItem(timestamp: 4, close: 4),
    ]

    let values = MACalculator(period: 3).calculate(for: items)

    #expect(values.count == 4)
    #expect(values[0] == nil)
    #expect(values[1] == nil)
    #expect(values[2] == 2)
    #expect(values[3] == 3)
}

@Test func emaCalculatorCalculatesExpectedValues() {
    let items: [any ChartItem] = [
        TestChartItem(timestamp: 1, close: 1),
        TestChartItem(timestamp: 2, close: 2),
        TestChartItem(timestamp: 3, close: 3),
        TestChartItem(timestamp: 4, close: 4),
    ]

    let values = EMACalculator(period: 3).calculate(for: items)

    #expect(values.count == 4)
    #expect(values[0] == 1)
    #expect(values[1] == 1.5)
    #expect(values[2] == 2)
    #expect(values[3] == 3)
}

#endif
