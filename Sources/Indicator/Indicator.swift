//
//  Indicator.swift
//  KLine
//
//  Created by iya on 2024/11/1.
//

import Foundation

//public struct Indicator: Equatable, Sendable {
//    
//    public let name: String
//    
//    public init(name: String) {
//        self.name = name
//    }
//    
//    public static var vol   : Indicator { Indicator(name: "VOL") }
//    public static var ma    : Indicator { Indicator(name: "MA") }
//    public static var ema   : Indicator { Indicator(name: "EMA") }
//    public static var rsi   : Indicator { Indicator(name: "RSI") }
//    public static var macd  : Indicator { Indicator(name: "MACD") }
//}

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
        case ma(_ period: Int)
        case ema(_ period: Int)
        case rsi(_ period: Int)
        case macd(_ shortPeriod: Int, _ longPeriod: Int, _ signalPeriod: Int)
        
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

//extension Indicator {
//    
//    public var keys: [Indicator.Key] {
//        switch self {
//        case .vol:
//            return [.vol]
//        case .ma:
//            return [.ma(5), .ma(10), .ma(20)]
//        case .ema:
//            return [.ema(5), .ema(10), .ema(20)]
//        case .rsi:
//            return [.rsi(5), .rsi(10), .rsi(20)]
//        case .macd:
//            return [.macd(12, 26, 9)]
//        }
//    }
//}
