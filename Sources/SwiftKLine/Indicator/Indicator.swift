//
//  Indicator.swift
//  SwiftKLine
//
//  Created by iya on 2024/11/1.
//

import Foundation

public enum Indicator: String, CaseIterable, Sendable {
    case ma     = "MA"
    case ema    = "EMA"
    case boll   = "BOLL"
    case sar    = "SAR"
    case vol    = "VOL"
    case rsi    = "RSI"
    case macd   = "MACD"
    
    var isMain: Bool {
        switch self {
        case .ma, .ema, .boll, .sar: return true
        default: return false
        }
    }
}

// TODO: 需要能动态配置每个 indicator 下对应的 key
extension Indicator {
    
    private final class KeyStorage {
        var keyMap: [Indicator: [Indicator.Key]] =  [
            .ma:    [.ma(5), .ma(10), .ma(20)],
            .ema:   [.ema(5), .ema(10), .ema(20)],
            .boll:  [.boll],
            .sar:   [.sar],
            .vol:   [.vol],
            .rsi:   [.rsi(6), .rsi(12), .rsi(24)],
            .macd:  [.macd]
        ]
    }
    
    nonisolated(unsafe) private static let storage = KeyStorage()
    
    var keys: [Key] {
        Self.storage.keyMap[self] ?? []
    }
}

extension Indicator {
    
    public enum Key: Hashable, Sendable, CustomStringConvertible {
        case ma(_ period: Int)
        case ema(_ period: Int)
        case boll
        case sar
        case vol
        case rsi(_ period: Int)
        case macd
        
        public var description: String {
            switch self {
            case let .ma(period):   return "MA(\(period))"
            case let .ema(period):  return "EMA(\(period))"
            case .boll: return "BOLL"
            case .sar: return "SAR(0.02,0.2)"
            case .vol:  return "VOL"
            case let .rsi(period):  return "RSI\(period)"
            case let .macd: return "MACD(12,26,9)"
            }
        }
    }
}
