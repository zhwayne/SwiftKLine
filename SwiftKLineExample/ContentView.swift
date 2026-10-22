//
//  ContentView.swift
//  SwiftKLineExample
//
//  Created by zhwayne on 2025/04/13.
//

import SwiftUI
import SwiftKLine

/// Display choices exposed by the example’s main-chart segmented control.
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

/// Assembles the example’s presentation picker, period picker, and reusable chart view.
struct ContentView: View {
    
    @State private var period: ChartPeriod = .oneMinute
    @State private var chartMode: ChartDisplayMode = .candlestick
    private let usesOfflineData: Bool

    /// Keeps previews offline while normal app launches use Binance.
    init(usesOfflineData: Bool = false) {
        self.usesOfflineData = usesOfflineData
    }
    
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
                
                ChartPeriodPicker(period: $period)
                KLineSwiftUIView(period: period, mode: chartMode, usesOfflineData: usesOfflineData)
            }
        }
        .contentMargins(.vertical, 16)
    }
}

#Preview {
    ContentView(usesOfflineData: true)
}
