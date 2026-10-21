//
//  IndicatorPlugin.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/05/17.
//

import SwiftKLineCore
import Foundation

    /// The stable identity; registering the same ID replaces the existing plugin in that registry.
@MainActor public protocol IndicatorPlugin: Sendable {
    var id: IndicatorID { get }
    /// The title displayed by the indicator selection control.
    var title: String { get }
    /// The default selection region; overlay plugins can also be selected on the main chart.
    var placement: IndicatorPlacement { get }
    /// Standard output identities, including parameters needed by calculations and styles.
    var defaultSeriesKeys: [SeriesKey] { get }

    /// Creates Sendable calculators; output keys must match the renderer’s requested keys.
    func makeCalculators(configuration: ChartConfiguration) -> [any IndicatorCalculator]
    /// Creates main-actor renderers with semantic IDs suitable for reuse.
    @MainActor func makeRenderers(configuration: ChartConfiguration) -> [any ChartRenderer]
}

