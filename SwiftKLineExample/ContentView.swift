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
    private let usesDemoData: Bool

    /// Selects offline sample data for previews or the --demo launch mode; normal runs use the exchange provider.
    init(usesDemoData: Bool = ProcessInfo.processInfo.arguments.contains("--demo")) {
        self.usesDemoData = usesDemoData
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
                KLineSwiftUIView(period: period, mode: chartMode, usesDemoData: usesDemoData)
            }
        }
        .contentMargins(.vertical, 16)
    }
}

#Preview {
    ContentView(usesDemoData: true)
}
