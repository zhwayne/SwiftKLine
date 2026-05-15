import Foundation

@MainActor
public struct KLineChartConfiguration {
    public var data: KLineDataSourceConfiguration
    public var appearance: KLineAppearanceConfiguration
    public var content: KLineChartContentStyle
    public var indicators: KLineIndicatorSelectionConfiguration
    public var features: KLineFeatureOptions
    public var plugins: KLinePluginRegistry

    public init(
        data: KLineDataSourceConfiguration = .deferred,
        appearance: KLineAppearanceConfiguration = .configuration(KLineConfiguration()),
        content: KLineChartContentStyle = .candlestick,
        indicators: KLineIndicatorSelectionConfiguration = .init(),
        features: KLineFeatureOptions = .default,
        plugins: KLinePluginRegistry = .default
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

public enum KLineDataSourceConfiguration {
    case provider(any KLineItemProvider)
    case deferred
}

@MainActor
public enum KLineAppearanceConfiguration {
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

public enum KLineIndicatorSelection: Hashable, Sendable, Codable {
    case builtIn(KLineIndicator)
    case custom(KLineIndicatorID)
}

public struct KLineIndicatorSelectionConfiguration: Equatable, Sendable {
    public var main: [KLineIndicatorSelection]
    public var sub: [KLineIndicatorSelection]

    public init(
        main: [KLineIndicatorSelection] = [],
        sub: [KLineIndicatorSelection] = []
    ) {
        self.main = main
        self.sub = sub
    }
}

public struct KLineFeatureOptions: OptionSet, Sendable {
    public let rawValue: Int

    public static let liveUpdates = KLineFeatureOptions(rawValue: 1 << 0)
    public static let gapRecovery = KLineFeatureOptions(rawValue: 1 << 1)
    public static let indicatorPersistence = KLineFeatureOptions(rawValue: 1 << 2)
    public static let `default`: KLineFeatureOptions = [.liveUpdates, .gapRecovery, .indicatorPersistence]

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}
