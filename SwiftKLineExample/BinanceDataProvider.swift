//
//  BinanceDataProvider.swift
//  KLineDemo
//
//  Created by iya on 2025/4/13.
//  Copyright © 2025 iya. All rights reserved.
//

import Foundation
import SwiftKLine
import SwiftyJSON

/// 表示单个 K 线数据点。
struct BinanceKLineItem: KLineItem {
    let opening: Double      // 开盘价
    let closing: Double      // 收盘价
    let highest: Double      // 最高价
    let lowest: Double       // 最低价
    let volume: Double       // 成交量
    let value: Double        // 成交额
    let timestamp: Int       // 时间戳
}

final class BinanceDataProvider: KLineItemProvider {
    private let symbol: String
    private let period: KLinePeriod
    private let size = 1000
    private lazy var endDate = Date()
    private let session = URLSession(configuration: URLSessionConfiguration.default)
    
    init(symbol: String, period: KLinePeriod) {
        self.symbol = symbol
        self.period = period
    }
    
    func fetchKLineItems(forPage page: Int) async throws -> [any KLineItem] {
        let end = endDate.addingTimeInterval(TimeInterval(-period.seconds * size * page))
        let start = end.addingTimeInterval(TimeInterval(-period.seconds * size))
        return try await fetchKLineItems(from: start, to: end)
    }

    func fetchKLineItems(from start: Date, to end: Date) async throws -> [any KLineItem] {
        let startMs = Int(start.timeIntervalSince1970 * 1000)
        let endMs = Int(end.timeIntervalSince1970 * 1000)
        var urlComponents = URLComponents(string: "https://data-api.binance.vision/api/v3/klines")!
        urlComponents.queryItems = [
            URLQueryItem(name: "interval", value: period.identifier),
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "startTime", value: "\(startMs)"),
            URLQueryItem(name: "endTime", value: "\(endMs)"),
            URLQueryItem(name: "limit", value: "\(size)")
        ]
        guard let url = urlComponents.url else { return [] }
        let (data, _) = try await session.data(from: url)
        let json = try JSON(data: data)
        return Self.decodeItems(from: json)
    }

    // MARK: - Live Stream （Provider 自行管理连接与解码）
    func liveStream() -> AsyncStream<any KLineItem> {
        let path = "wss://stream.binance.com:443/ws/\(symbol.lowercased())@kline_\(period.identifier)"
        guard let url = URL(string: path) else { return AsyncStream { $0.finish() } }
        return AsyncStream { continuation in
            Task {
                let client = WebSocketClient(config: .init(url: url))
                try? await client.connect()
                for await msg in client.messages {
                    switch msg {
                    case .text(let text):
                        guard let data = text.data(using: .utf8), let item = Self.decodeItem(from: data) else { continue }
                        continuation.yield(item)
                    case .data(let data):
                        guard let item = Self.decodeItem(from: data) else { continue }
                        continuation.yield(item)
                    }
                }
                continuation.finish()
            }
        }
    }

    private static func decodeItem(from data: Data) -> (any KLineItem)? {
        // Binance kline 结构：{"k":{ "t": startTime(ms), "o": "open", "h": "high", "l": "low", "c": "close", "v": "volume", "q": "quoteVolume" }}
        let json = try? JSON(data: data)
        let k = json?["k"]
        guard let k else { return nil }
        let ts = k["t"].intValue / 1000
        return BinanceKLineItem(
            opening: k["o"].doubleValue,
            closing: k["c"].doubleValue,
            highest: k["h"].doubleValue,
            lowest:  k["l"].doubleValue,
            volume:  k["v"].doubleValue,
            value:   k["q"].doubleValue,
            timestamp: ts
        )
    }

    private static func decodeItems(from json: JSON) -> [any KLineItem] {
        json.arrayValue.map { json -> any KLineItem in
            let array = json.arrayValue
            return BinanceKLineItem(
                opening: array[1].doubleValue,
                closing: array[4].doubleValue,
                highest: array[2].doubleValue,
                lowest: array[3].doubleValue,
                volume: array[5].doubleValue,
                value: array[7].doubleValue,
                timestamp: array[0].intValue / 1000
            )
        }
    }

}
