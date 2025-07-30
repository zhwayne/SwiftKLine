//
//  BinanceDataProvider.swift
//  KLineDemo
//
//  Created by iya on 2025/4/13.
//  Copyright © 2025 iya. All rights reserved.
//

import Foundation
import KLine
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
    typealias Item = BinanceKLineItem

    private let symbol: String
    private let period: KLinePeriod
    private let size = 1000
    private lazy var endDate = Int(Date().timeIntervalSince1970) * 1000
    private let session = URLSession(configuration: URLSessionConfiguration.default)
    
    init(symbol: String = "BTCUSDT", period: KLinePeriod) {
        self.symbol = symbol
        self.period = period
    }
    
    func fetchKLineItems(forPage page: Int) async throws -> [Item] {
        // https://developers.binance.com/docs/zh-CN/binance-spot-api-docs/rest-api/market-data-endpoints#k%E7%BA%BF%E6%95%B0%E6%8D%AE
        var urlComponents = URLComponents(string: "https://data-api.binance.vision/api/v3/klines")!
        let endTime = endDate - period.seconds * size * 1000 * page
        let startTime = endTime - period.seconds * size * 1000
        urlComponents.queryItems = [
            URLQueryItem(name: "interval", value: period.identifier),
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "startTime", value: "\(startTime)"),
            URLQueryItem(name: "endTime", value: "\(endTime)"),
            URLQueryItem(name: "limit", value: "\(size)")
        ]
        let url = urlComponents.url!
        
        let (data, _) = try await session.data(from: url)
        let json = try JSON(data: data)
        let items = json.arrayValue.map { json in
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
        return items
    }
}
