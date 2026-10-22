//
//  ChartConfiguration.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/05/17.
//

import SwiftKLineCore
import UIKit

/// Candle-loading capabilities and the existing indicator-persistence option.
public struct ChartFeatures: OptionSet, Sendable {
    /// The underlying candle-capability bit mask.
    public let rawValue: Int
    /// Creates a capability set from its underlying bit mask.
    public init(rawValue: Int) { self.rawValue = rawValue }
    /// Consumes complete live candle snapshots.
    public static let liveUpdates = ChartFeatures(rawValue: 1 << 0)
    /// Recovers missing history before reconnecting live data.
    public static let gapRecovery = ChartFeatures(rawValue: 1 << 1)
    /// Persists the existing indicator selector state.
    public static let indicatorPersistence = ChartFeatures(rawValue: 1 << 2)
    static let candleLoading: ChartFeatures = [.liveUpdates, .gapRecovery]
    /// Enables live snapshots, missing-history recovery, and indicator persistence.
    public static let all: ChartFeatures = [.liveUpdates, .gapRecovery, .indicatorPersistence]
}

/// A primary time axis with explicit semantic identity and real candle boundaries.
public struct CandleSource: Sendable {
    /// Semantic source identity; change it when data or candle-boundary semantics change.
    public let id: String
    /// Creates the primary provider only when its loading session starts.
    let provider: @Sendable () -> any ChartItemProvider
    /// Resolves [open, end) from an existing candle-open Unix timestamp in seconds.
    let candleInterval: @Sendable (Int) -> Range<Date>

    /// Creates a source with exchange- or calendar-aware candle intervals.
    public init(id: String, candleInterval: @escaping @Sendable (Int) -> Range<Date>,
                provider: @escaping @Sendable () -> any ChartItemProvider) {
        self.id = id
        self.candleInterval = candleInterval
        self.provider = provider
    }

    /// Creates a genuinely fixed-duration source; calendar periods need the other initializer.
    public init(id: String, duration: TimeInterval,
                provider: @escaping @Sendable () -> any ChartItemProvider) {
        precondition(duration.isFinite && duration > 0)
        self.init(id: id, candleInterval: { timestamp in
            let start = Date(timeIntervalSince1970: TimeInterval(timestamp))
            return start..<start.addingTimeInterval(duration)
        }, provider: provider)
    }
}

/// Invalid declarations are rejected before they can mutate a running chart.
public enum ChartConfigurationError: Error, Equatable {
    /// The primary source must have a nonempty semantic identity.
    case emptySourceID
    /// Plugin list entries must have nonempty stable identities.
    case emptyPluginID
    /// Two enabled declarations cannot share one plugin identity.
    case duplicatePluginID(String)
}

/// The complete declarative input shared by UIKit and SwiftUI.
@MainActor
public struct ChartConfiguration {
    /// The primary candle session and time-axis boundary rules.
    public let source: CandleSource
    /// Current visual settings, applied without restarting providers.
    public var appearance: ChartAppearance
    /// The main price presentation, independent of plugin selection.
    public var content: ChartType
    /// Enabled features in stable declaration and panel order.
    public private(set) var plugins: [any ChartPlugin]
    /// Initial selection for the existing UI; persisted selection retains its original precedence.
    public var indicators: IndicatorSelectionState?
    /// Candle loading and selector persistence; external plugins own their loading policy.
    public var features: ChartFeatures

    /// Validates all source and plugin identities before creating a complete configuration.
    public init(source: CandleSource, appearance: ChartAppearance = ChartAppearance(),
                content: ChartType = .candlestick, plugins: [any ChartPlugin] = [],
                indicators: IndicatorSelectionState? = nil, features: ChartFeatures = .all) throws {
        guard !source.id.isEmpty else { throw ChartConfigurationError.emptySourceID }
        var ids = Set<String>()
        for plugin in plugins {
            guard !plugin.id.isEmpty else { throw ChartConfigurationError.emptyPluginID }
            guard ids.insert(plugin.id).inserted else {
                throw ChartConfigurationError.duplicatePluginID(plugin.id)
            }
        }
        self.source = source
        self.appearance = appearance
        self.content = content
        self.plugins = plugins
        self.indicators = indicators
        self.features = features
    }
    /// The selector is an adapter; all calculations and rendering still use one plugin pipeline.
    func includingSelectedIndicators(_ selected: [any ChartPlugin]) -> ChartConfiguration {
        var result = self
        let declared = Set(plugins.map(\.id))
        result.plugins = selected.filter { !declared.contains($0.id) } + plugins
        return result
    }

}
