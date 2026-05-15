//
//  KLineSwiftUIView.swift
//  SwiftKLineExample
//
//  Created by iya on 2025/4/13.
//

import SwiftUI
import SwiftKLine

struct KLineSwiftUIView: View {
    
    let period: KLinePeriod
    let mode: ChartDisplayMode
    
    var body: some View {
        KLineRepresentable(period: period, mode: mode)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct KLineRepresentable: UIViewRepresentable {
    
    let period: KLinePeriod
    let mode: ChartDisplayMode
    
    typealias UIViewType = KLineView

    func makeUIView(context: Context) -> KLineView {
        let chart = ChartConfiguration(
            data: .deferred,
            appearance: .theme(.midnight),
            content: mode == .candlestick ? .candlestick : .timeSeries,
            indicators: .init(
                main: [.builtIn(.ma)],
                sub: [.builtIn(.vol), .builtIn(.macd)]
            ),
            features: [.liveUpdates, .gapRecovery, .indicatorPersistence],
            plugins: .default
        )
        let store = KLineUserDefaultsIndicatorSelectionStore()
        return KLineView(chart: chart, indicatorSelectionStore: store)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func updateUIView(_ uiView: KLineView, context: Context) {
        if context.coordinator.period != period {
            let provider = BinanceDataProvider(symbol: "BTCUSDT", period: period)
            uiView.loadData(using: provider)
            uiView.invalidateIntrinsicContentSize()
            context.coordinator.period = period
        }

        switch mode {
        case .candlestick:
            uiView.setChartContentStyle(.candlestick)
        case .timeSeries:
            uiView.setChartContentStyle(.timeSeries)
        }
    }

    final class Coordinator {
        var period: KLinePeriod?
    }
}

#Preview {
    KLineSwiftUIView(period: .fiveMinutes, mode: .candlestick)
}
