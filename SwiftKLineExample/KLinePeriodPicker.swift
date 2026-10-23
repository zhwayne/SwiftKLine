//
//  KLinePeriodPicker.swift
//  SwiftKLineExample
//
//  Created by zhwayne on 2025/04/13.
//

import SwiftUI
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

/// An example period selector bound to the chart's shared selection.
struct ChartPeriodPicker: View {
    @Binding var period: ChartPeriod
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(DemoChartPeriod.all) { option in
                    Button {
                        period = option.period
                    } label: {
                        let isSelected = option.period == period
                        Text(option.title)
                            .tint(Color(.label).opacity(0.8))
                            .font(.system(size: 12))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(.label).opacity(isSelected ? 0.1 : 0)))
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 16)
    }
}
