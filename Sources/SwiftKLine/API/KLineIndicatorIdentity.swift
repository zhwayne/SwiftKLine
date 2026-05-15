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

/// 渲染器在图表中的挂载区域。
public enum RendererPlacement: Sendable, Hashable {
    case main
    case mainIndicator(IndicatorID)
    case sub(IndicatorID)
    case overlay
    case crosshair
}
