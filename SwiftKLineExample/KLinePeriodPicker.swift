//
//  KLinePeriodPicker.swift
//  SwiftKLineExample
//
//  Created by zhwayne on 2025/04/13.
//

import SwiftUI
import SwiftKLine

/// An application period selector bound to screen state.
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
