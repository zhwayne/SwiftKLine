//
//  KLinePeriodPicker.swift
//  SwiftKLineExample
//
//  Created by iya on 2025/4/13.
//

import SwiftUI
import SwiftKLine

struct KLinePeriodPicker: View {
    
    @Binding var period: KLinePeriod
    
    private let allPeriods: [(KLinePeriod, String)] = [
        (.oneMinute, "1分"),
        (.threeMinutes, "3分"),
        (.fiveMinutes, "5分"),
        (.fifteenMinutes, "15分"),
        (.thirtyMinutes, "30分"),
        (.oneHour, "1时"),
        (.twoHours, "2时"),
        (.fourHours, "4时"),
        (.sixHours, "6时"),
        (.eightHours, "8时"),
        (.twelveHours, "12时"),
        (.oneDay, "1天"),
        (.threeDays, "3天"),
        (.oneWeek, "1周"),
        (.oneMonth, "1月")
    ]
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(allPeriods, id: \.0.identifier) { (period, title) in
                    Button {
                        self.period = period
                    } label: {
                        let isSelected = period == self.period
                        Text(title)
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
