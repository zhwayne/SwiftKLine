//
//  Indicator.swift
//  KLine
//
//  Created by iya on 2024/11/1.
//

import Foundation

public enum Indicator: String, Sendable {
    case vol = "VOL"
    case ma  = "MA"
    case ema = "EMA"
    case rsi = "RSI"
    case macd = "MACD"
}

/// 不同类型的指标及其相关参数。
extension Indicator {
    public enum Key: Hashable, Sendable {
        case vol
        case ma(period: Int)
        case ema(period: Int)
        case rsi(period: Int)
        case macd(shortPeriod: Int, longPeriod: Int, signalPeriod: Int)
        
        public var description: String {
            switch self {
            case .vol:
                return "VOL"
            case .ma(let period):
                return "MA\(period)"
            case .ema(let period):
                return "EMA\(period)"
            case .rsi(let period):
                return "RSI\(period)"
            case .macd(let short, let long, let signal):
                return "MACD(\(short),\(long),\(signal))"
            }
        }
    }
}
