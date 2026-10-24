//
//  DemoChartPeriod.swift
//  SwiftKLineExample
//
//  Created by zhwayne on 2025/04/13.
//

import SwiftKLine

/// One application-supported period and its localized display title.
struct DemoChartPeriod: Identifiable {
    let period: ChartPeriod
    let title: String
    var id: String { period.identifier }

    static let all: [DemoChartPeriod] = [
        DemoChartPeriod(period: .oneMinute, title: "1分"),
        DemoChartPeriod(period: .threeMinutes, title: "3分"),
        DemoChartPeriod(period: .fiveMinutes, title: "5分"),
        DemoChartPeriod(period: .fifteenMinutes, title: "15分"),
        DemoChartPeriod(period: .thirtyMinutes, title: "30分"),
        DemoChartPeriod(period: .oneHour, title: "1时"),
        DemoChartPeriod(period: .twoHours, title: "2时"),
        DemoChartPeriod(period: .fourHours, title: "4时"),
        DemoChartPeriod(period: .sixHours, title: "6时"),
        DemoChartPeriod(period: .eightHours, title: "8时"),
        DemoChartPeriod(period: .twelveHours, title: "12时"),
        DemoChartPeriod(period: .oneDay, title: "1天"),
        DemoChartPeriod(period: .threeDays, title: "3天"),
        DemoChartPeriod(period: .oneWeek, title: "1周"),
        DemoChartPeriod(period: .oneMonth, title: "1月")
    ]

}
