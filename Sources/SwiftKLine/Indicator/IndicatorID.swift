import Foundation

/// 指标的开放标识，供内置指标和外部自定义指标使用。
public struct IndicatorID: Hashable, Sendable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }

    public var description: String {
        rawValue
    }

    public static let ma = IndicatorID("builtin.ma")
    public static let ema = IndicatorID("builtin.ema")
    public static let wma = IndicatorID("builtin.wma")
    public static let boll = IndicatorID("builtin.boll")
    public static let sar = IndicatorID("builtin.sar")
    public static let vol = IndicatorID("builtin.vol")
    public static let rsi = IndicatorID("builtin.rsi")
    public static let macd = IndicatorID("builtin.macd")

    public static let allBuiltIn: [IndicatorID] = [.ma, .ema, .wma, .boll, .sar, .vol, .rsi, .macd]

    public var isBuiltIn: Bool { rawValue.hasPrefix("builtin.") }
}

/// 指标输出序列的稳定键，用于在计算、存储和渲染之间解耦数据来源。
public struct SeriesKey: Hashable, Sendable, CustomStringConvertible {
    public let indicatorID: IndicatorID
    public let name: String
    public let parameters: [String: String]

    public init(
        indicatorID: IndicatorID,
        name: String,
        parameters: [String: String] = [:]
    ) {
        self.indicatorID = indicatorID
        self.name = name
        self.parameters = parameters
    }

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

/// 指标在图表中的默认展示区域。
public enum IndicatorPlacement: Sendable, Equatable {
    case main
    case sub
    case overlay
}

extension SeriesKey {
    public static func ma(period: Int) -> SeriesKey {
        SeriesKey(indicatorID: .ma, name: "MA", parameters: ["period": "\(period)"])
    }
    public static func ema(period: Int) -> SeriesKey {
        SeriesKey(indicatorID: .ema, name: "EMA", parameters: ["period": "\(period)"])
    }
    public static func wma(period: Int) -> SeriesKey {
        SeriesKey(indicatorID: .wma, name: "WMA", parameters: ["period": "\(period)"])
    }
    public static func boll(period: Int, k: Double) -> SeriesKey {
        SeriesKey(indicatorID: .boll, name: "BOLL", parameters: ["period": "\(period)", "k": "\(k)"])
    }
    public static let sar = SeriesKey(indicatorID: .sar, name: "SAR")
    public static let vol = SeriesKey(indicatorID: .vol, name: "VOL")
    public static func rsi(period: Int) -> SeriesKey {
        SeriesKey(indicatorID: .rsi, name: "RSI", parameters: ["period": "\(period)"])
    }
    public static func macd(shortPeriod: Int, longPeriod: Int, signalPeriod: Int) -> SeriesKey {
        SeriesKey(indicatorID: .macd, name: "MACD", parameters: [
            "shortPeriod": "\(shortPeriod)", "longPeriod": "\(longPeriod)", "signalPeriod": "\(signalPeriod)"
        ])
    }
}

/// 渲染器在图表中的挂载区域。
public enum RendererPlacement: Sendable, Hashable {
    case main
    case mainIndicator(IndicatorID)
    case sub(IndicatorID)
    case overlay
    case crosshair
}
