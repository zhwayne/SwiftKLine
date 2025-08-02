//
//  Indicator.swift
//  KLine
//
//  Created by iya on 2024/11/1.
//

import Foundation

public enum Indicator: String, CaseIterable, Sendable {
    case ma  = "MA"
    case ema = "EMA"
    case vol = "VOL"
    case rsi = "RSI"
    case macd = "MACD"
    
    var isMain: Bool {
        switch self {
        case .ma, .ema: return true
        default: return false
        }
    }
}

extension Indicator {
    
    private final class KeyStorage {
        var keyMap: [Indicator: [Indicator.Key]] =  [
            .ma:  [.ma(5), .ma(10), .ma(20)],
            .ema: [.ema(5), .ema(10), .ema(20)],
            .vol: [.vol],
            .rsi: [.rsi(6), .rsi(12), .rsi(24)],
            .macd: [.macd]
        ]
    }
    
    nonisolated(unsafe) private static let storage = KeyStorage()
    
    var keys: [Key] {
        Self.storage.keyMap[self] ?? []
    }
}

extension Indicator {
    
    public enum Key: Hashable, Sendable {
        case ma(_ period: Int)
        case ema(_ period: Int)
        case vol
        case rsi(_ period: Int)
        case macd
        
        public var description: String {
            switch self {
            case let .ma(period):   return "MA\(period)"
            case let .ema(period):  return "EMA\(period)"
            case .vol:  return "VOL"
            case let .rsi(period):  return "RSI\(period)"
            case let .macd: return "MACD(12,26,9)"
            }
        }
    }
}
