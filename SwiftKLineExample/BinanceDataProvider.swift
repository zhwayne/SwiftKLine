//
//  BinanceDataProvider.swift
//  SwiftKLineExample
//
//  Created by zhwayne on 2025/04/13.
//

import Foundation
import SwiftKLine

/// An exchange-specific example provider using URLSession and Decodable, with no chart-package networking dependency.
///
/// Historical requests return at most 1,000 rows per response. Each live subscription owns an independent client,
/// and bounded buffering permits dropping intermediate snapshots when a consumer falls behind.
final class BinanceDataProvider: ChartItemProvider {
    private let symbol: String
    private let period: ChartPeriod
    private let size = 1000
    private let endDate = Date()
    private let session = URLSession(configuration: .default)
    // Calendar months cannot be represented by a fixed number of seconds.
    /// Uses fixed periods except for calendar months, whose identity must use exact candle-open timestamps.
    var candlePeriod: ChartPeriod? { period == .oneMonth ? nil : period }

    /// Captures the market, period, and initial paging boundary for this provider session.
    init(symbol: String, period: ChartPeriod) {
        self.symbol = symbol
        self.period = period
    }

    /// Requests the nominal period-based window for the given page, with page zero ending at the captured session boundary.
    func fetchChartItems(forPage page: Int) async throws -> [any ChartItem] {
        let end = endDate.addingTimeInterval(-Double(period.seconds) * Double(size) * Double(page))
        return try await fetchChartItems(from: end.addingTimeInterval(-Double(period.seconds) * Double(size)), to: end)
    }

    /// Fetches one response of at most 1,000 rows for an inclusive interval and validates the HTTP status before decoding.
    func fetchChartItems(from start: Date, to end: Date) async throws -> [any ChartItem] {
        var components = URLComponents(string: "https://data-api.binance.vision/api/v3/klines")!
        components.queryItems = [
            URLQueryItem(name: "interval", value: period.identifier),
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "startTime", value: "\(Int(start.timeIntervalSince1970 * 1000))"),
            URLQueryItem(name: "endTime", value: "\(Int(end.timeIntervalSince1970 * 1000))"),
            URLQueryItem(name: "limit", value: "\(size)")
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([HistoryCandle].self, from: data).map(\.candle)
    }

    /// Creates a fresh, bounded snapshot stream and closes its client when the stream terminates.
    func liveStream() -> AsyncStream<any ChartItem> {
        let path = "wss://stream.binance.com:443/ws/\(symbol.lowercased())@kline_\(period.identifier)"
        guard let url = URL(string: path) else { return AsyncStream { $0.finish() } }
        return AsyncStream(bufferingPolicy: .bufferingNewest(512)) { continuation in
            let client = WebSocketClient(config: .init(url: url))
            let producer = Task {
                do { try await client.connect() }
                catch { continuation.finish(); await client.disconnect(); return }
                for await message in client.messages {
                    guard !Task.isCancelled else { break }
                    let data: Data
                    switch message {
                    case let .text(text): data = Data(text.utf8)
                    case let .data(bytes): data = bytes
                    }
                    guard let envelope = try? JSONDecoder().decode(LiveEnvelope.self, from: data) else { continue }
                    continuation.yield(envelope.k.candle)
                }
                await client.disconnect()
                continuation.finish()
            }
            // Cancelling AsyncStream does not automatically cancel its producer or close the socket.
            continuation.onTermination = { @Sendable _ in
                producer.cancel()
                Task { await client.disconnect() }
            }
        }
    }
}

/// Decodes exchange string-encoded decimal values and rejects non-finite or malformed numbers.
private struct DecimalValue: Decodable {
    let value: Double
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = Double(string), value.isFinite else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected a finite price or volume")
        }
        self.value = value
    }
}

/// Decodes the exchange’s positional OHLCV array, converting millisecond open time to Unix seconds.
private struct HistoryCandle: Decodable {
    let candle: Candle
    init(from decoder: any Decoder) throws {
        var row = try decoder.unkeyedContainer()
        let timestamp = try row.decode(Int.self) / 1000
        let open = try row.decode(DecimalValue.self).value
        let high = try row.decode(DecimalValue.self).value
        let low = try row.decode(DecimalValue.self).value
        let close = try row.decode(DecimalValue.self).value
        let volume = try row.decode(DecimalValue.self).value
        _ = try row.decode(Int.self) // close time
        let value = try row.decode(DecimalValue.self).value
        candle = Candle(timestamp: timestamp, open: open, high: high, low: low, close: close, volume: volume, value: value)
    }
}

/// Decodes the exchange’s nested live-candle envelope into complete immutable candle snapshots.
private struct LiveEnvelope: Decodable {
    let k: LiveCandle
    struct LiveCandle: Decodable {
        let t: Int
        let o, h, l, c, v, q: DecimalValue
        var candle: Candle {
            Candle(timestamp: t / 1000, open: o.value, high: h.value, low: l.value,
                   close: c.value, volume: v.value, value: q.value)
        }
    }
}
