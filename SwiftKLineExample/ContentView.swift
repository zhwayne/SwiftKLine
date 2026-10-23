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
@MainActor
struct ContentView: View {
    @State private var selection = ChartSelection(period: .oneMinute,
        indicators: IndicatorSelection(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol, .macd]))
    @State private var chartMode: ChartDisplayMode = .candlestick
    private let usesOfflineData: Bool
    private let stateStore: any ChartStateStore

    /// Keeps previews offline while normal app launches use Binance.
    init(
        usesOfflineData: Bool = false,
        stateStore: any ChartStateStore = UserDefaultsChartStateStore()
    ) {
        self.usesOfflineData = usesOfflineData
        let effectiveStore: any ChartStateStore = usesOfflineData ? MemoryChartStateStore() : stateStore
        self.stateStore = effectiveStore
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
                
                ChartPeriodPicker(period: $selection.period)
                KLineSwiftUIView(
                    mode: chartMode,
                    usesOfflineData: usesOfflineData,
                    selection: $selection,
                    stateStore: stateStore
                )
            }
        }
        .contentMargins(.vertical, 16)
    }
}

#Preview {
    ContentView(usesOfflineData: false)
}
