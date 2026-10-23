//
//  IndicatorID.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2026/05/17.
//

import Foundation

/// An open indicator identity shared by selection, plugins, and series keys.
///
/// The "builtin." namespace is reserved for built-in indicators; use an application-specific prefix for custom plugins.
public struct IndicatorID: Hashable, Sendable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    /// The stable identifier used for hashing, persistence, and plugin lookup.
    public let rawValue: String

    /// Creates an identifier without validating or normalizing its namespace.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates an identifier from a string literal without changing its contents.
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }

    /// The unchanged raw identifier used in diagnostics.
    public var description: String {
        rawValue
    }

    /// The built-in simple moving average identity.
    public static let ma = IndicatorID("builtin.ma")
    /// The built-in exponential moving average identity.
    public static let ema = IndicatorID("builtin.ema")
    /// The built-in weighted moving average identity.
    public static let wma = IndicatorID("builtin.wma")
    /// The built-in Bollinger bands identity.
    public static let boll = IndicatorID("builtin.boll")
    /// The built-in parabolic SAR indicator ID.
    public static let sar = IndicatorID("builtin.sar")
    /// The built-in bull-bear index identity.
    public static let bbi = IndicatorID("builtin.bbi")
    /// The built-in volume-weighted moving average identity.
    public static let vwma = IndicatorID("builtin.vwma")
    /// The built-in Donchian channel identity.
    public static let donchian = IndicatorID("builtin.donchian")
    /// The built-in SuperTrend identity; its default display title is the short “SUPER” form.
    public static let superTrend = IndicatorID("builtin.super")
    /// The built-in Ichimoku Kinko Hyo identity; its default display title is the short “ICHI” form.
    public static let ichimoku = IndicatorID("builtin.ichi")
    /// The built-in volume identity.
    public static let vol = IndicatorID("builtin.vol")
    /// The built-in relative strength index identity.
    public static let rsi = IndicatorID("builtin.rsi")
    /// The built-in MACD identity.
    public static let macd = IndicatorID("builtin.macd")

    public static let kdj = IndicatorID("builtin.kdj")
    public static let cci = IndicatorID("builtin.cci")
    public static let wr = IndicatorID("builtin.wr")
    public static let dmi = IndicatorID("builtin.dmi")
    public static let atr = IndicatorID("builtin.atr")
    public static let obv = IndicatorID("builtin.obv")
    public static let roc = IndicatorID("builtin.roc")
    public static let mfi = IndicatorID("builtin.mfi")
    public static let trix = IndicatorID("builtin.trix")

    /// All built-in indicator IDs in their standard presentation order.
    public static let allBuiltIn: [IndicatorID] = [
        .ma, .ema, .wma, .boll, .sar, .bbi, .vwma, .donchian,
        .superTrend, .ichimoku, .vol, .rsi, .macd,
        .kdj, .cci, .wr, .dmi, .atr, .obv, .roc, .mfi, .trix
    ]

    /// Whether the identifier uses the built-in namespace; this does not verify plugin registration.
    public var isBuiltIn: Bool { rawValue.hasPrefix("builtin.") }
}

/// The complete identity of one calculated output series.
///
/// Include every parameter that changes the output. Calculation, storage, styles, and renderer reuse depend
/// on equality of this key; identical display names alone do not imply interchangeable series.
public struct SeriesKey: Hashable, Sendable, CustomStringConvertible {
    /// The indicator or plugin that owns this output.
    public let indicatorID: IndicatorID
    /// The output’s display name, such as "MA" or "MACD".
    public let name: String
    /// String-encoded calculation parameters participating in equality and hashing.
    public let parameters: [String: String]

    /// Creates an output identity from its owning indicator, display name, and calculation parameters.
    ///
    /// - Parameters:
    ///   - indicatorID: Owning indicator identity.
    ///   - name: Output display name.
    ///   - parameters: All settings that distinguish this output from another instance.
    public init(
        indicatorID: IndicatorID,
        name: String,
        parameters: [String: String] = [:]
    ) {
        self.indicatorID = indicatorID
        self.name = name
        self.parameters = parameters
    }

    /// A deterministic diagnostic string with parameter names sorted lexicographically.
    public var description: String {
        guard !parameters.isEmpty else {
            return "\(indicatorID).\(name)"
        }

        let parameterDescription = parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ",")
        return "\(indicatorID).\(name)(\(parameterDescription))"
    }
}

extension SeriesKey {
    /// KDJ identity including the lookback and both recursive smoothing periods.
    public static func kdj(period: Int, kPeriod: Int, dPeriod: Int) -> SeriesKey {
        SeriesKey(indicatorID: .kdj, name: "KDJ", parameters: [
            "period": "\(period)", "kPeriod": "\(kPeriod)", "dPeriod": "\(dPeriod)"
        ])
    }

    /// DMI identity including the DI window and ADX smoothing period.
    public static func dmi(diPeriod: Int, adxPeriod: Int) -> SeriesKey {
        SeriesKey(indicatorID: .dmi, name: "DMI", parameters: [
            "diPeriod": "\(diPeriod)", "adxPeriod": "\(adxPeriod)"
        ])
    }

    public static func cci(period: Int) -> SeriesKey {
        SeriesKey(indicatorID: .cci, name: "CCI", parameters: ["period": "\(period)"])
    }
    public static func wr(period: Int) -> SeriesKey {
        SeriesKey(indicatorID: .wr, name: "WR", parameters: ["period": "\(period)"])
    }
    public static func atr(period: Int) -> SeriesKey {
        SeriesKey(indicatorID: .atr, name: "ATR", parameters: ["period": "\(period)"])
    }
    public static let obv = SeriesKey(indicatorID: .obv, name: "OBV")
    public static func roc(period: Int) -> SeriesKey {
        SeriesKey(indicatorID: .roc, name: "ROC", parameters: ["period": "\(period)"])
    }
    public static func mfi(period: Int) -> SeriesKey {
        SeriesKey(indicatorID: .mfi, name: "MFI", parameters: ["period": "\(period)"])
    }
    public static func trix(period: Int) -> SeriesKey {
        SeriesKey(indicatorID: .trix, name: "TRIX", parameters: ["period": "\(period)"])
    }

    /// Creates the simple moving average output key for the supplied candle period.
    public static func ma(period: Int) -> SeriesKey {
        SeriesKey(indicatorID: .ma, name: "MA", parameters: ["period": "\(period)"])
    }
    /// Creates the exponential moving average output key for the supplied candle period.
    public static func ema(period: Int) -> SeriesKey {
        SeriesKey(indicatorID: .ema, name: "EMA", parameters: ["period": "\(period)"])
    }
    /// Creates the weighted moving average output key for the supplied candle period.
    public static func wma(period: Int) -> SeriesKey {
        SeriesKey(indicatorID: .wma, name: "WMA", parameters: ["period": "\(period)"])
    }
    /// Creates a Bollinger key containing the period and standard-deviation multiplier.
    public static func boll(period: Int, k: Double) -> SeriesKey {
        SeriesKey(indicatorID: .boll, name: "BOLL", parameters: ["period": "\(period)", "k": "\(k)"])
    }
    /// The parabolic SAR series key for standard acceleration settings.
    public static let sar = SeriesKey(indicatorID: .sar, name: "SAR")
    /// Creates a SAR key including acceleration settings; standard settings reuse the canonical sar key.
    public static func sar(afStart: Double, afStep: Double, afMax: Double) -> SeriesKey {
        if afStart == 0.02, afStep == 0.02, afMax == 0.2 { return .sar }
        return SeriesKey(indicatorID: .sar, name: "SAR", parameters: [
            "afStart": "\(afStart)", "afStep": "\(afStep)", "afMax": "\(afMax)"
        ])
    }

    /// The standard BBI output key using MA periods 3, 6, 12, and 24.
    public static let bbi = SeriesKey(indicatorID: .bbi, name: "BBI", parameters: [
        "periods": "3,6,12,24"
    ])

    /// Creates a BBI key for the supplied moving-average periods.
    ///
    /// Periods are sorted before encoding so configurations that differ only in argument order share one
    /// series identity and one calculator cache entry. The standard periods reuse the canonical ``bbi`` key.
    /// - Parameter periods: Moving-average periods averaged by the bull-bear index.
    public static func bbi(periods: [Int]) -> SeriesKey {
        let canonical = periods.sorted()
        if canonical == [3, 6, 12, 24] { return .bbi }
        return SeriesKey(indicatorID: .bbi, name: "BBI", parameters: [
            "periods": canonical.map(String.init).joined(separator: ",")
        ])
    }

    /// Creates a volume-weighted moving average output key for the supplied candle period.
    public static func vwma(period: Int) -> SeriesKey {
        SeriesKey(indicatorID: .vwma, name: "VWMA", parameters: ["period": "\(period)"])
    }

    /// Creates a Donchian channel output key for the supplied lookback period.
    public static func donchian(period: Int) -> SeriesKey {
        SeriesKey(indicatorID: .donchian, name: "DC", parameters: ["period": "\(period)"])
    }

    /// Creates a SuperTrend output key containing the ATR period and band multiplier.
    ///
    /// - Parameters:
    ///   - period: The ATR smoothing window.
    ///   - multiplier: The ATR distance of the trailing stop from the candle midpoint.
    public static func superTrend(period: Int, multiplier: Double) -> SeriesKey {
        SeriesKey(indicatorID: .superTrend, name: "SUPER", parameters: [
            "period": "\(period)", "multiplier": "\(multiplier)"
        ])
    }

    /// Creates an Ichimoku Kinko Hyo output key containing every window and the plot displacement.
    ///
    /// - Parameters:
    ///   - tenkanPeriod: The Tenkan-sen lookback.
    ///   - kijunPeriod: The Kijun-sen lookback.
    ///   - senkouBPeriod: The Senkou Span B lookback.
    ///   - displacement: The number of chart positions used to shift the spans and Chikou.
    public static func ichimoku(
        tenkanPeriod: Int,
        kijunPeriod: Int,
        senkouBPeriod: Int,
        displacement: Int
    ) -> SeriesKey {
        SeriesKey(indicatorID: .ichimoku, name: "ICHI", parameters: [
            "tenkanPeriod": "\(tenkanPeriod)",
            "kijunPeriod": "\(kijunPeriod)",
            "senkouBPeriod": "\(senkouBPeriod)",
            "displacement": "\(displacement)"
        ])
    }

    /// The built-in volume identity.
    public static let vol = SeriesKey(indicatorID: .vol, name: "VOL")
    /// Creates the relative strength index output key for the supplied candle period.
    public static func rsi(period: Int) -> SeriesKey {
        SeriesKey(indicatorID: .rsi, name: "RSI", parameters: ["period": "\(period)"])
    }
    /// Creates a MACD key containing all three EMA and signal periods.
    public static func macd(shortPeriod: Int, longPeriod: Int, signalPeriod: Int) -> SeriesKey {
        SeriesKey(indicatorID: .macd, name: "MACD", parameters: [
            "shortPeriod": "\(shortPeriod)", "longPeriod": "\(longPeriod)", "signalPeriod": "\(signalPeriod)"
        ])
    }
}
