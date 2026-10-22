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
    /// The built-in volume identity.
    public static let vol = IndicatorID("builtin.vol")
    /// The built-in relative strength index identity.
    public static let rsi = IndicatorID("builtin.rsi")
    /// The built-in MACD identity.
    public static let macd = IndicatorID("builtin.macd")

    /// All built-in indicator IDs in their standard presentation order.
    public static let allBuiltIn: [IndicatorID] = [.ma, .ema, .wma, .boll, .sar, .vol, .rsi, .macd]

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
