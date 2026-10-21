//
//  KLineSwiftUIView.swift
//  SwiftKLineExample
//
//  Created by zhwayne on 2025/04/13.
//

import SwiftUI
import SwiftKLine

/// Demonstrates stable period-based provider identity and dynamic presentation through the public SwiftUI adapter.
struct KLineSwiftUIView: View {
    let period: ChartPeriod
    let mode: ChartDisplayMode
    let usesDemoData: Bool

    var body: some View {
        KLineChart(sourceID: period, options: ChartOptions(
            appearance: .theme(.midnight),
            indicators: IndicatorSelectionState(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol, .macd])
        ),
                   content: mode == .candlestick ? .candlestick : .timeSeries) {
            if usesDemoData {
                DemoProvider(period: period)
            } else {
                BinanceDataProvider(symbol: "BTCUSDT", period: period)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// Offline data keeps previews deterministic and independent of exchange/network availability.
/// Supplies deterministic offline candles for previews and visual validation without opening a network connection.
final class DemoProvider: ChartItemProvider, Sendable {
    private let period: ChartPeriod
    init(period: ChartPeriod = .oneMinute) { self.period = period }

    func fetchChartItems(forPage page: Int) async throws -> [any ChartItem] {
        guard page == 0 else { return [] }
        return (0..<100).map { index in
            let price = 100 + sin(Double(index) * 0.3) * 10
            return Candle(timestamp: 1_700_000_000 + index * period.seconds, open: price - 2,
                          high: price + 3, low: price - 3, close: price, volume: 1000)
        }
    }
    func fetchChartItems(from start: Date, to end: Date) async throws -> [any ChartItem] { [] }
}

#Preview {
    KLineChart(sourceID: "preview", options: ChartOptions(features: [])) { DemoProvider() }
        .fixedSize(horizontal: false, vertical: true)
}
