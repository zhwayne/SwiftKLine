//
//  ContentView.swift
//  SwiftKLineExample
//
//  Created by iya on 2025/4/13.
//

import SwiftUI
import SwiftKLine

enum ChartDisplayMode: String, CaseIterable, Identifiable {
    case candlestick
    case timeSeries
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .candlestick: return "K线"
        case .timeSeries: return "分时"
        }
    }
}

struct ContentView: View {
    
    @State private var period: KLinePeriod = .oneMinute
    @State private var chartMode: ChartDisplayMode = .candlestick
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("图表模式", selection: $chartMode) {
                    ForEach(ChartDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                
                KLinePeriodPicker(period: $period)
                KLineSwiftUIView(period: period, mode: chartMode)
            }
        }
        .contentMargins(.vertical, 16)
    }
}

#Preview {
    ContentView()
}
