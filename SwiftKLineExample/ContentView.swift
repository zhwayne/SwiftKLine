//
//  ContentView.swift
//  SwiftKLineExample
//
//  Created by zhwayne on 2025/04/13.
//

import SwiftUI
import SwiftKLine

/// Assembles the example’s presentation picker, period picker, and reusable chart view.
@MainActor
struct ContentView: View {
    @Bindable var state: ChartScreenState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("图表模式", selection: $state.mode) {
                    ForEach(ChartDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                
                ChartPeriodPicker(period: $state.period)
                KLineSwiftUIView(
                    mode: state.mode,
                    usesOfflineData: state.usesOfflineData,
                    period: state.period,
                    indicators: $state.indicators,
                    availableIndicators: state.availableIndicators
                )
            }
        }
        .contentMargins(.vertical, 16)
    }
}

#Preview {
    ContentView(state: ChartScreenState(usesOfflineData: true))
}
