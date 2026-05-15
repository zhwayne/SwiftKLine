//
//  KLineIndicator.swift
//  SwiftKLine
//
//  Created by iya on 2024/11/1.
//

import Foundation

public enum KLineIndicator: String, CaseIterable, Sendable, Codable {
    case ma     = "MA"
    case ema    = "EMA"
    case wma    = "WMA"
    case boll   = "BOLL"
    case sar    = "SAR"
    case vol    = "VOL"
    case rsi    = "RSI"
    case macd   = "MACD"
    
    var isMain: Bool {
        switch self {
        case .ma, .ema, .wma, .boll, .sar: return true
        default: return false
        }
    }
}

// TODO: 需要能动态配置每个 indicator 下对应的 key
extension KLineIndicator {
    
    static let defaultKeyMap: [KLineIndicator: [KLineIndicator.Key]] = [
        .ma:    [.ma(5), .ma(10), .ma(20)],
        .ema:   [.ema(5), .ema(10), .ema(20)],
        .wma:   [.wma(5), .wma(10), .wma(20)],
        .boll:  [.boll(period: 20, k: 2.0)],
        .sar:   [.sar],
        .vol:   [.vol],
        .rsi:   [.rsi(6), .rsi(12), .rsi(24)],
        .macd:  [.macd(shortPeriod: 12, longPeriod: 26, signalPeriod: 9)]
    ]

    var defaultKeys: [Key] {
        Self.defaultKeyMap[self] ?? []
    }
}

extension KLineIndicator {
    
    public enum Key: Hashable, Sendable, CustomStringConvertible {
        case ma(_ period: Int)
        case ema(_ period: Int)
        case wma(_ period: Int)
        case boll(period: Int, k: Double)
        case sar
        case vol
        case rsi(_ period: Int)
        case macd(shortPeriod: Int, longPeriod: Int, signalPeriod: Int)
        
        public var description: String {
            switch self {
            case let .ma(period):   return "MA(\(period))"
            case let .ema(period):  return "EMA(\(period))"
            case let .wma(period):  return "WMA(\(period))"
            case let .boll(period, k): return "BOLL(\(period),\(k))"
            case .sar: return "SAR(0.02,0.2)"
            case .vol:  return "VOL"
            case let .rsi(period):  return "RSI\(period)"
            case let .macd(short, long, signal): return "MACD(\(short),\(long),\(signal))"
            }
        }
    }
}

public extension KLineIndicator {
    var kLineID: KLineIndicatorID {
        KLineIndicatorID("builtin.\(rawValue.lowercased())")
    }

    init?(kLineID: KLineIndicatorID) {
        let prefix = "builtin."
        guard kLineID.rawValue.hasPrefix(prefix) else { return nil }
        let rawValue = String(kLineID.rawValue.dropFirst(prefix.count)).uppercased()
        self.init(rawValue: rawValue)
    }
}

public extension KLineIndicator.Key {
    var kLineSeriesKey: KLineSeriesKey {
        switch self {
        case let .ma(period):
            return KLineSeriesKey(indicatorID: KLineIndicator.ma.kLineID, name: "MA", parameters: ["period": "\(period)"])
        case let .ema(period):
            return KLineSeriesKey(indicatorID: KLineIndicator.ema.kLineID, name: "EMA", parameters: ["period": "\(period)"])
        case let .wma(period):
            return KLineSeriesKey(indicatorID: KLineIndicator.wma.kLineID, name: "WMA", parameters: ["period": "\(period)"])
        case let .boll(period, k):
            return KLineSeriesKey(indicatorID: KLineIndicator.boll.kLineID, name: "BOLL", parameters: ["k": "\(k)", "period": "\(period)"])
        case .sar:
            return KLineSeriesKey(indicatorID: KLineIndicator.sar.kLineID, name: "SAR")
        case .vol:
            return KLineSeriesKey(indicatorID: KLineIndicator.vol.kLineID, name: "VOL")
        case let .rsi(period):
            return KLineSeriesKey(indicatorID: KLineIndicator.rsi.kLineID, name: "RSI", parameters: ["period": "\(period)"])
        case let .macd(shortPeriod, longPeriod, signalPeriod):
            return KLineSeriesKey(
                indicatorID: KLineIndicator.macd.kLineID,
                name: "MACD",
                parameters: [
                    "longPeriod": "\(longPeriod)",
                    "shortPeriod": "\(shortPeriod)",
                    "signalPeriod": "\(signalPeriod)"
                ]
            )
        }
    }
}
