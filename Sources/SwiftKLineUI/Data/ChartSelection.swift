//
//  ChartSelection.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/10/23.
//

import SwiftKLineCore

/// The period and indicators selected for one chart.
/// ChartView validates this value before applying and persisting it.
public struct ChartSelection: Codable, Equatable, Sendable {
    /// The period used by the application's configuration factory.
    public var period: ChartPeriod
    /// The ordered main- and lower-panel indicator choices.
    public var indicators: IndicatorSelection

    /// Creates an explicit selection. An empty indicator selection hides all built-in indicators.
    public init(period: ChartPeriod, indicators: IndicatorSelection) {
        self.period = period
        self.indicators = indicators
    }
}
