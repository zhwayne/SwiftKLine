import Foundation

@MainActor
public struct ChartOptions {
    public var appearance: AppearanceConfiguration
    public var content: ChartType
    public var indicators: IndicatorSelectionState?
    public var features: ChartFeatures
    public var plugins: PluginRegistry

    public init(
        appearance: AppearanceConfiguration = .configuration(ChartConfiguration()),
        content: ChartType = .candlestick,
        indicators: IndicatorSelectionState? = nil,
        features: ChartFeatures = .all,
        plugins: PluginRegistry = .default
    ) {
        self.appearance = appearance
        self.content = content
        self.indicators = indicators
        self.features = features
        self.plugins = plugins
    }

    public var resolvedConfiguration: ChartConfiguration {
        appearance.resolvedConfiguration
    }
}

@MainActor
public enum AppearanceConfiguration {
    case configuration(ChartConfiguration)
    case theme(ChartConfiguration.ThemePreset)

    var resolvedConfiguration: ChartConfiguration {
        switch self {
        case let .configuration(configuration):
            return configuration
        case let .theme(preset):
            return .themed(preset)
        }
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