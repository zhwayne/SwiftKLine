//
//  IndicatorConfiguration.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/10/24.
//

import SwiftKLineCore

/// Calculation parameters for built-in indicators, independent of appearance and application choices.
public struct IndicatorConfiguration: Equatable, Sendable {
    /// Complete output keys for overridden indicators; omitted indicators use their standard keys.
    public var seriesKeys: [BuiltInIndicator: [SeriesKey]]

    public init(seriesKeys: [BuiltInIndicator: [SeriesKey]] = [:]) {
        self.seriesKeys = seriesKeys
    }

    /// Returns the configured output keys in calculation and drawing order.
    public func indicatorKeys(for indicator: BuiltInIndicator) -> [SeriesKey] {
        seriesKeys[indicator] ?? indicator.defaultSeriesKeys
    }
}
