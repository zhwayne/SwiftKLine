//
//  KLineSwiftUIView.swift
//  SwiftKLineExample
//
//  Created by zhwayne on 2025/04/13.
//

import SwiftUI
import SwiftKLine

/// Displays Binance candles while retaining deterministic offline preview fixtures.
@MainActor
struct KLineSwiftUIView: View {
    let mode: ChartDisplayMode
    let usesOfflineData: Bool
    @Binding var selection: ChartSelection
    let stateStore: any ChartStateStore
    private let appearance = ChartAppearance.themed(.midnight)

    var body: some View {
        VStack(spacing: 0) {
            KLineChart(
                selection: $selection,
                availablePeriods: DemoChartPeriod.all.map(\.period),
                stateStore: stateStore,
                configuration: configuration
            )
                .fixedSize(horizontal: false, vertical: true)
            IndicatorSelectorView(indicators: appearance.indicators, selection: $selection.indicators)
        }
    }

    private func configuration(for selection: ChartSelection) -> ChartConfiguration {
        let period = selection.period, offline = usesOfflineData
        let source = CandleSource(id: "BTCUSDT:\(period.identifier):\(period.seconds):\(offline)", candleInterval: { timestamp in
            let start = Date(timeIntervalSince1970: Double(timestamp))
            if period == .oneMonth {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                return start..<calendar.date(byAdding: .month, value: 1, to: start)!
            }
            return start..<start.addingTimeInterval(Double(period.seconds))
        }, provider: {
            if offline { return DemoProvider(period: period) }
            return BinanceDataProvider(symbol: "BTCUSDT", period: period)
        })
        // These fixed declarations are unique; construction cannot fail for user-supplied identities.
        return try! ChartConfiguration(source: source, appearance: appearance,
            content: mode == .candlestick ? .candlestick : .timeSeries,
            features: usesOfflineData ? [] : [.liveUpdates, .gapRecovery])
    }
}

// Offline data keeps previews deterministic and independent of exchange/network availability.
/// Supplies deterministic offline candles for previews and visual validation without opening a network connection.
final class DemoProvider: ChartItemProvider, Sendable {
    private let period: ChartPeriod
    init(period: ChartPeriod = .oneMinute) { self.period = period }

    func fetchChartItems(forPage page: Int) async throws -> [any ChartItem] {
        guard page == 0 else { return [] }
        return Self.candles(for: period)
    }

    /// Shared immutable fixtures keep candle prices and sample executions reproducible across previews.
    static func candles(for period: ChartPeriod) -> [Candle] {
        (0..<100).map { index in
            let price = 100 + sin(Double(index) * 0.3) * 10
            return Candle(timestamp: 1_700_000_000 + index * period.seconds, open: price - 2,
                          high: price + 3, low: price - 3, close: price, volume: 1000)
        }
    }
    func fetchChartItems(from start: Date, to end: Date) async throws -> [any ChartItem] { [] }
}

#Preview("Chart") {
    KLineSwiftUIView(
        mode: .candlestick,
        usesOfflineData: true,
        selection: .constant(.init(period: .oneMinute,
            indicators: .init(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol, .macd]))),
        stateStore: MemoryChartStateStore()
    )
}
