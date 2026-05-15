import Foundation

@MainActor
public struct ChartConfiguration {
    public var data: DataSourceConfiguration
    public var appearance: AppearanceConfiguration
    public var content: ChartType
    public var indicators: IndicatorSelectionConfiguration
    public var features: ChartFeatures
    public var plugins: PluginRegistry

    public init(
        data: DataSourceConfiguration = .manual,
        appearance: AppearanceConfiguration = .configuration(KLineConfiguration()),
        content: ChartType = .candlestick,
        indicators: IndicatorSelectionConfiguration = .init(),
        features: ChartFeatures = .all,
        plugins: PluginRegistry = .default
    ) {
        self.data = data
        self.appearance = appearance
        self.content = content
        self.indicators = indicators
        self.features = features
        self.plugins = plugins
    }

    public var resolvedConfiguration: KLineConfiguration {
        appearance.resolvedConfiguration
    }
}

public enum DataSourceConfiguration {
    case provider(any KLineItemProvider)
    case manual
}

@MainActor
public enum AppearanceConfiguration {
    case configuration(KLineConfiguration)
    case theme(KLineConfiguration.ThemePreset)

    var resolvedConfiguration: KLineConfiguration {
        switch self {
        case let .configuration(configuration):
            return configuration
        case let .theme(preset):
            return .themed(preset)
        }
    }
}

public enum IndicatorSelection: Hashable, Sendable, Codable {
    case builtIn(KLineIndicator)
    case custom(IndicatorID)
}

public struct IndicatorSelectionConfiguration: Equatable, Sendable {
    public var main: [IndicatorSelection]
    public var sub: [IndicatorSelection]

    public init(
        main: [IndicatorSelection] = [],
        sub: [IndicatorSelection] = []
    ) {
        self.main = main
        self.sub = sub
    }
}

public struct ChartFeatures: OptionSet, Sendable {
    public let rawValue: Int

    public static let liveUpdates = ChartFeatures(rawValue: 1 << 0)
    public static let gapRecovery = ChartFeatures(rawValue: 1 << 1)
    public static let indicatorPersistence = ChartFeatures(rawValue: 1 << 2)
    public static let all: ChartFeatures = [.liveUpdates, .gapRecovery, .indicatorPersistence]

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}
