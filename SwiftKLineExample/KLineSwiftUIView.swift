//
//  KLineSwiftUIView.swift
//  SwiftKLineExample
//
//  Created by iya on 2025/4/13.
//

import SwiftUI
import SwiftKLine

struct KLineSwiftUIView: View {
    
    let period: ChartPeriod
    let mode: ChartDisplayMode
    
    var body: some View {
        KLineRepresentable(period: period, mode: mode)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct KLineRepresentable: UIViewRepresentable {
    
    let period: ChartPeriod
    let mode: ChartDisplayMode
    
    typealias UIViewType = ChartView

    func makeUIView(context: Context) -> ChartView {
        let options = ChartOptions(
            appearance: .theme(.midnight),
            content: mode == .candlestick ? .candlestick : .timeSeries,
            indicators: IndicatorSelectionState(
                main: [.ma],
                sub: [.vol, .macd]
            ),
            features: [.liveUpdates, .gapRecovery, .indicatorPersistence],
            plugins: .default
        )
        let store = UserDefaultsIndicatorSelectionStore()
        return ChartView(options: options, indicatorSelectionStore: store)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func updateUIView(_ uiView: ChartView, context: Context) {
        if context.coordinator.period != period {
            let provider = BinanceDataProvider(symbol: "BTCUSDT", period: period)
            uiView.loadData(using: provider)
            uiView.invalidateIntrinsicContentSize()
            context.coordinator.period = period
        }

        switch mode {
        case .candlestick:
            uiView.setContentStyle(.candlestick)
        case .timeSeries:
            uiView.setContentStyle(.timeSeries)
        }
    }

    final class Coordinator {
        var period: ChartPeriod?
    }
}

#Preview {
    KLineSwiftUIView(period: .fiveMinutes, mode: .candlestick)
}
