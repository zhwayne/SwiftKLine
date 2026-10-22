//
//  TradeMarkerExample.swift
//  SwiftKLineExample
//
//  Created by zhwayne on 2026/10/21.
//

#if canImport(UIKit)
import Foundation
import SwiftKLine

/// An application-owned, finite provider demonstrating independent cursor pagination.
struct SnapshotTradeProvider: RangeDataProvider {
    let trades: [TradeMarker]
    private let pageSize: Int

    /// Small pages let previews exercise cursor continuation as the viewport changes.
    init(trades: [TradeMarker], pageSize: Int = 100) {
        precondition(pageSize > 0)
        self.trades = trades
        self.pageSize = pageSize
    }

    func fetch(in range: Range<Date>, cursor: Int?) async throws -> RangePage<TradeMarker, Int> {
        let matches = trades.filter { range.contains($0.timestamp) }
            .sorted { $0.timestamp < $1.timestamp }
        let start = min(max(cursor ?? 0, 0), matches.count)
        let end = start + min(pageSize, matches.count - start)
        return RangePage(items: Array(matches[start..<end]), nextCursor: end < matches.count ? end : nil)
    }
}

/// Supplies synthetic executions through separate, short market-history requests.
///
/// This example does not read chart snapshots or share candle pagination. Replace it with an
/// account service for actual executions; the market provider here only supplies plausible prices.
struct DemoTradeProvider: RangeDataProvider {
    let provider: any ChartItemProvider
    let period: ChartPeriod

    /// Advances an independent time cursor by at most ten nominal candle periods per page.
    func fetch(in range: Range<Date>, cursor: Date?) async throws -> RangePage<TradeMarker, Date> {
        let start = cursor ?? range.lowerBound
        guard range.contains(start) else { return RangePage(items: [], nextCursor: nil) }
        let end = min(start.addingTimeInterval(Double(period.seconds) * 10), range.upperBound)
        let items = try await provider.fetchChartItems(from: start, to: end)
        let trades = demoTradeMarkers(for: items, period: period).filter { (start..<end).contains($0.timestamp) }
        return RangePage(items: trades, nextCursor: end < range.upperBound ? end : nil)
    }
}

/// Creates synthetic executions inside candle prices; these are not real trading signals.
///
/// Absolute time buckets keep identities and directions stable across overlapping queries and pages.
func demoTradeMarkers(for candles: [any ChartItem], period: ChartPeriod) -> [TradeMarker] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return candles.compactMap { candle in
        let date = Date(timeIntervalSince1970: Double(candle.timestamp))
        let ordinal: Int
        if period == .oneMonth {
            let components = calendar.dateComponents([.year, .month], from: date)
            ordinal = components.year! * 12 + components.month! - 1
        } else {
            ordinal = Int(floor(Double(candle.timestamp) / Double(period.seconds)))
        }
        guard ordinal % 5 == 2 else { return nil }
        let side: TradeMarker.Side = (ordinal / 5).isMultiple(of: 2) ? .buy : .sell
        let spread = max(candle.high - candle.low, 0)
        return TradeMarker(id: "demo-execution-\(candle.timestamp)", timestamp: date,
                           price: side == .buy ? candle.low + spread * 0.15 : candle.high - spread * 0.15,
                           side: side)
    }.sorted { $0.timestamp < $1.timestamp }
}

/// Composes application data through public library APIs without changing the default example screen.
///
/// Change source identities whenever the symbol, period, account, or query semantics change.
/// A production trade provider can replace the snapshot provider without changing the candle source.
@MainActor
func tradeMarkerConfiguration(candles: [Candle], trades: [TradeMarker]) throws -> ChartConfiguration {
    try ChartConfiguration(
        source: CandleSource(
            id: "BTCUSDT:1m",
            duration: 60,
            provider: { SnapshotProvider(items: candles) }
        ),
        plugins: [
            TradeMarkers(
                id: "account.trades",
                sourceID: "account-42:BTCUSDT",
                provider: { SnapshotTradeProvider(trades: trades) }
            )
        ],
        indicators: IndicatorSelectionState(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol, .macd]),
        features: []
    )
}
#endif
