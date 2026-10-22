//
//  BuiltInIndicator.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2024/11/01.
//

import SwiftKLineCore
import Foundation

/// The built-in catalog used by selection controls and default plugin construction.
public enum BuiltInIndicator: String, CaseIterable, Sendable, Codable {
    /// The built-in simple moving average indicator.
    case ma       = "MA"
    /// The built-in exponential moving average indicator.
    case ema      = "EMA"
    /// The built-in weighted moving average indicator.
    case wma      = "WMA"
    /// The built-in Bollinger bands indicator.
    case boll     = "BOLL"
    /// The built-in parabolic SAR indicator.
    case sar      = "SAR"
    /// The built-in bull-bear index indicator.
    case bbi      = "BBI"
    /// The built-in volume-weighted moving average indicator.
    case vwma     = "VWMA"
    /// The built-in Donchian channel indicator.
    case donchian = "DONCHIAN"
    /// The built-in SuperTrend overlay; its stable ID uses the short “super” name.
    case superTrend = "SUPER"
    /// The built-in Ichimoku Kinko Hyo overlay; its stable ID uses the short “ichi” name.
    case ichimoku   = "ICHI"
    /// The built-in volume indicator.
    case vol      = "VOL"
    /// The built-in relative strength indicator.
    case rsi      = "RSI"
    /// The built-in MACD indicator.
    case macd     = "MACD"

    case kdj = "KDJ"
    case cci = "CCI"
    case wr = "WR"
    case dmi = "DMI"
    case atr = "ATR"
    case obv = "OBV"
    case roc = "ROC"
    case mfi = "MFI"
    case trix = "TRIX"

    /// Whether the indicator overlays the price chart rather than occupying a lower panel.
    public var isMain: Bool {
        switch self {
        case .ma, .ema, .wma, .boll, .sar, .bbi, .vwma, .donchian,
             .superTrend, .ichimoku:
            return true
        default: return false
        }
    }

    /// The stable open ID in the reserved built-in namespace.
    public var id: IndicatorID {
        IndicatorID("builtin.\(rawValue.lowercased())")
    }

    /// The standard output keys and calculation periods for this indicator.
    public var defaultSeriesKeys: [SeriesKey] {
        switch self {
        case .ma:  return [.ma(period: 5), .ma(period: 10), .ma(period: 20)]
        case .ema: return [.ema(period: 5), .ema(period: 10), .ema(period: 20)]
        case .wma: return [.wma(period: 5), .wma(period: 10), .wma(period: 20)]
        case .boll: return [.boll(period: 20, k: 2.0)]
        case .sar: return [.sar]
        case .bbi: return [.bbi]
        case .vwma: return [.vwma(period: 20)]
        case .donchian: return [.donchian(period: 20)]
        case .superTrend: return [.superTrend(period: 10, multiplier: 3)]
        case .ichimoku: return [.ichimoku(
            tenkanPeriod: 9,
            kijunPeriod: 26,
            senkouBPeriod: 52,
            displacement: 26
        )]
        case .vol: return [.vol]
        case .rsi: return [.rsi(period: 6), .rsi(period: 12), .rsi(period: 24)]
        case .macd: return [.macd(shortPeriod: 12, longPeriod: 26, signalPeriod: 9)]
        case .kdj: return [.kdj(period: 9, kPeriod: 3, dPeriod: 3)]
        case .cci: return [.cci(period: 20)]
        case .wr: return [.wr(period: 14)]
        case .dmi: return [.dmi(diPeriod: 14, adxPeriod: 14)]
        case .atr: return [.atr(period: 14)]
        case .obv: return [.obv]
        case .roc: return [.roc(period: 9)]
        case .mfi: return [.mfi(period: 14)]
        case .trix: return [.trix(period: 18)]
        }
    }

    /// Resolves a known built-in ID, returning nil for custom or unknown IDs.
    public init?(id: IndicatorID) {
        let prefix = "builtin."
        guard id.rawValue.hasPrefix(prefix) else { return nil }
        let rawValue = String(id.rawValue.dropFirst(prefix.count)).uppercased()
        self.init(rawValue: rawValue)
    }
}
