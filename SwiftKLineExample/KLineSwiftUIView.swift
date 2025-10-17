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
        let view = KLineView()
        return view
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func updateUIView(_ uiView: KLineView, context: Context) {
        if context.coordinator.period != period {
            let provider = BinanceDataProvider(symbol: "BTCUSDT", period: period)
            uiView.setProvider(provider)
            uiView.invalidateIntrinsicContentSize()
            context.coordinator.period = period
        }

        switch mode {
        case .candlestick:
            uiView.useCandlesticks()
        case .timeSeries:
            uiView.useTimeSeries()
        }
    }

    final class Coordinator {
        var period: KLinePeriod?
    }
}

#Preview {
    KLineSwiftUIView(period: .fiveMinutes, mode: .candlestick)
}
