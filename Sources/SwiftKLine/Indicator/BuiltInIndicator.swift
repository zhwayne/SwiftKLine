//
//  BuiltInIndicator.swift
//  SwiftKLine
//
//  Created by iya on 2024/11/1.
//

import Foundation

public enum BuiltInIndicator: String, CaseIterable, Sendable, Codable {
    case ma     = "MA"
    case ema    = "EMA"
    case wma    = "WMA"
    case boll   = "BOLL"
    case sar    = "SAR"
    case vol    = "VOL"
    case rsi    = "RSI"
    case macd   = "MACD"

    public var isMain: Bool {
        switch self {
        case .ma, .ema, .wma, .boll, .sar: return true
        default: return false
        }
    }

    public var id: IndicatorID {
        IndicatorID("builtin.\(rawValue.lowercased())")
    }

    public var defaultSeriesKeys: [SeriesKey] {
        switch self {
        case .ma:  return [.ma(period: 5), .ma(period: 10), .ma(period: 20)]
        case .ema: return [.ema(period: 5), .ema(period: 10), .ema(period: 20)]
        case .wma: return [.wma(period: 5), .wma(period: 10), .wma(period: 20)]
        case .boll: return [.boll(period: 20, k: 2.0)]
        case .sar: return [.sar]
        case .vol: return [.vol]
        case .rsi: return [.rsi(period: 6), .rsi(period: 12), .rsi(period: 24)]
        case .macd: return [.macd(shortPeriod: 12, longPeriod: 26, signalPeriod: 9)]
        }
    }

    public init?(id: IndicatorID) {
        let prefix = "builtin."
        guard id.rawValue.hasPrefix(prefix) else { return nil }
        let rawValue = String(id.rawValue.dropFirst(prefix.count)).uppercased()
        self.init(rawValue: rawValue)
    }
}