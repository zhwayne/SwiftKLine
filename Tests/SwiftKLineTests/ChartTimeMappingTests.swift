//
//  ChartTimeMappingTests.swift
//  SwiftKLineTests
//
//  Created by zhwayne on 2026/10/21.
//

#if canImport(UIKit)
import UIKit
import Foundation
import Testing
import SwiftKLineCore
@testable import SwiftKLineUI

@Test @MainActor func timeMappingRespectsMissingBucketsAndHalfOpenBoundaries() {
    let scroll = ChartScrollView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    let dims = CandleDimensions(width: 8, gap: 2)
    let layout = ChartLayout(scrollView: scroll, candleDimensions: dims)
    let context = ChartContext(indicatorSeriesStore: IndicatorSeriesStore(), items: [testCandle(60, 1), testCandle(180, 2)],
        appearance: ChartAppearance(), candleDimensions: dims, visibleRange: 0..<2, layout: layout,
        location: nil, selectedIndex: nil, candleInterval: { timestamp in
            let start = Date(timeIntervalSince1970: Double(timestamp)); return start..<start.addingTimeInterval(60)
        })
    #expect(context.candleIndex(containing: Date(timeIntervalSince1970: 60)) == 0)
    #expect(context.candleIndex(containing: Date(timeIntervalSince1970: 119.999)) == 0)
    #expect(context.candleIndex(containing: Date(timeIntervalSince1970: 120)) == nil)
    #expect(context.candleIndex(containing: Date(timeIntervalSince1970: 180)) == 1)
    #expect(context.candleIndex(containing: Date(timeIntervalSince1970: 240)) == nil)
}

@Test @MainActor func calendarMonthsUseActualBoundaries() {
    let scroll = ChartScrollView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    let dims = CandleDimensions(width: 8, gap: 2)
    let layout = ChartLayout(scrollView: scroll, candleDimensions: dims)
    let context = ChartContext(indicatorSeriesStore: IndicatorSeriesStore(),
        items: [testCandle(1_704_067_200, 1), testCandle(1_706_745_600, 2)],
        appearance: ChartAppearance(), candleDimensions: dims, visibleRange: 0..<2, layout: layout,
        location: nil, selectedIndex: nil, candleInterval: { timestamp in
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let start = Date(timeIntervalSince1970: Double(timestamp))
            return start..<calendar.date(byAdding: .month, value: 1, to: start)!
        })
    #expect(context.candleIndex(containing: Date(timeIntervalSince1970: 1_706_745_599)) == 0)
    #expect(context.candleIndex(containing: Date(timeIntervalSince1970: 1_706_745_600)) == 1)
    #expect(context.candleIndex(containing: Date(timeIntervalSince1970: 1_709_251_200)) == nil)
}

#endif
