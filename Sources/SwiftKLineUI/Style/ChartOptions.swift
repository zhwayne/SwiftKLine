//
//  ChartOptions.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/05/17.
//

import SwiftKLineCore
import Foundation

/// Creation-time chart assembly options, accessed on the main actor.
///
/// Appearance and plugins are resolved when a ChartView is created. Use chart commands for later content
/// or selection changes; SwiftUI needs a new view identity to replace creation-time appearance or plugins.
@MainActor
public struct ChartOptions {
    /// The visual configuration or theme preset resolved when creating the chart.
    public var appearance: AppearanceConfiguration
    /// The initial candlestick or time-series presentation.
    public var content: ChartType
    /// An optional initial selection, used when no nonempty persisted selection takes precedence.
    public var indicators: IndicatorSelectionState?
    /// Optional provider lifecycle and selection-persistence capabilities.
    public var features: ChartFeatures
    /// The instance-scoped plugin registry; configure it before creating the chart.
    public var plugins: PluginRegistry

    /// Creates assembly options. Nil indicators defer to persisted or configuration defaults, and default plugins are a fresh registry.
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

    /// Resolves the appearance into the visual configuration used to create the chart.
    public var resolvedConfiguration: ChartConfiguration {
        appearance.resolvedConfiguration
    }
}

/// Selects either an explicit visual configuration or a theme preset.
@MainActor
public enum AppearanceConfiguration {
    /// Uses the supplied visual configuration directly.
    case configuration(ChartConfiguration)
    /// Builds a visual configuration from a reusable theme preset.
    case theme(ChartConfiguration.ThemePreset)

    /// Converts the selected appearance representation into a concrete visual configuration.
    var resolvedConfiguration: ChartConfiguration {
        switch self {
        case let .configuration(configuration):
            return configuration
        case let .theme(preset):
            return .themed(preset)
        }
    }
}

/// Independent chart capabilities combined as an option set.
public struct ChartFeatures: OptionSet, Sendable {
    /// The underlying feature bit mask.
    public let rawValue: Int

    /// Consumes the provider’s live stream and pauses/resumes it with chart lifecycle events.
    public static let liveUpdates = ChartFeatures(rawValue: 1 << 0)
    /// Fetches missing intervals after foreground or network recovery before reconnecting live data.
    public static let gapRecovery = ChartFeatures(rawValue: 1 << 1)
    /// Enables selection persistence when constructing a chart through ChartOptions.
    public static let indicatorPersistence = ChartFeatures(rawValue: 1 << 2)
    /// Enables all currently defined chart capabilities.
    public static let all: ChartFeatures = [.liveUpdates, .gapRecovery, .indicatorPersistence]

    /// Creates a feature set from its bit mask, preserving unrecognized bits.
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}