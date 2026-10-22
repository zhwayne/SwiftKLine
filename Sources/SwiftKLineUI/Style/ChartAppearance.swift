//
//  ChartAppearance.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/05/17.
//

import SwiftKLineCore
import UIKit

/// A value configuration for appearance, section layout, built-in periods, and initial selection defaults.
///
/// Existing presentation and selector settings are preserved while plugins supply their data independently.
public struct ChartAppearance {

    /// The initial candle colors, width, and gap.
    public let candleStyle: CandleStyle
    /// The font used by indicator legends.
    public let legendFont: UIFont
    /// Optional watermark text displayed behind the main chart.
    public let watermarkText: String?
    /// The fixed heights of the main chart, time axis, indicator panels, and selector.
    public let layoutMetrics: LayoutMetrics
    /// Built-in indicators eligible for selection; custom features are declared in ChartConfiguration.plugins.
    public let indicators: [BuiltInIndicator]
    /// Built-in main indicators used for fallback selection and when resetting indicators.
    public let defaultMainIndicators: [BuiltInIndicator]
    /// Built-in lower indicators used for fallback selection and when resetting indicators.
    public let defaultSubIndicators: [BuiltInIndicator]

    private var indicatorStyleRegistry: [SeriesKey: any IndicatorStyle]
    private var indicatorKeyOverrides: [BuiltInIndicator: [SeriesKey]]

    /// Creates a visual and built-in indicator configuration.
    ///
    /// - Parameters:
    ///   - candleStyle: Initial candle appearance and horizontal dimensions.
    ///   - legendFont: Font for legend labels.
    ///   - watermarkText: Optional main-chart watermark.
    ///   - layoutMetrics: Section heights in points.
    ///   - indicators: Built-in indicators available to the selection control.
    ///   - defaultMainIndicators: Main-chart fallback and reset selection.
    ///   - defaultSubIndicators: Lower-panel fallback and reset selection.
    ///   - indicatorStyleRegistry: Complete style map; nil uses defaults. A supplied map replaces those defaults.
    ///   - indicatorKeyOverrides: Per-indicator output keys and parameters; omitted entries use built-in defaults.
    public init(
        candleStyle: CandleStyle = CandleStyle(),
        legendFont: UIFont = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
        watermarkText: String? = "Created by iyabb",
        layoutMetrics: LayoutMetrics = LayoutMetrics(),
        indicators: [BuiltInIndicator] = BuiltInIndicator.allCases,
        defaultMainIndicators: [BuiltInIndicator] = [],
        defaultSubIndicators: [BuiltInIndicator] = [],
        indicatorStyleRegistry: [SeriesKey: any IndicatorStyle]? = nil,
        indicatorKeyOverrides: [BuiltInIndicator: [SeriesKey]] = [:]
    ) {
        self.candleStyle = candleStyle
        self.legendFont = legendFont
        self.watermarkText = watermarkText
        self.layoutMetrics = layoutMetrics
        self.indicators = indicators
        self.defaultMainIndicators = defaultMainIndicators
        self.defaultSubIndicators = defaultSubIndicators
        self.indicatorStyleRegistry = indicatorStyleRegistry ?? Self.makeDefaultIndicatorStyles()
        self.indicatorKeyOverrides = indicatorKeyOverrides
    }

    /// Returns the exact style type for a series key, or nil when the key or requested type does not match.
    public func indicatorStyle<S>(for key: SeriesKey, type: S.Type) -> S? where S: IndicatorStyle {
        indicatorStyleRegistry[key] as? S
    }

    /// Returns overridden series keys for an indicator, or its standard series when no override exists.
    public func indicatorKeys(for indicator: BuiltInIndicator) -> [SeriesKey] {
        indicatorKeyOverrides[indicator] ?? indicator.defaultSeriesKeys
    }

    /// Builds styles for standard built-in periods; custom period keys need their own styles.
    static func makeDefaultIndicatorStyles() -> [SeriesKey: any IndicatorStyle] {
        [
            .ma(period: 5): LineStyle(strokeColor: .systemOrange),
            .ma(period: 10): LineStyle(strokeColor: .systemPink),
            .ma(period: 20): LineStyle(strokeColor: .systemTeal),
            .ema(period: 5): LineStyle(strokeColor: .systemOrange),
            .ema(period: 10): LineStyle(strokeColor: .systemPink),
            .ema(period: 20): LineStyle(strokeColor: .systemTeal),
            .wma(period: 5): LineStyle(strokeColor: .systemIndigo),
            .wma(period: 10): LineStyle(strokeColor: .systemBlue),
            .wma(period: 20): LineStyle(strokeColor: .systemGreen),
            .boll(period: 20, k: 2.0): LineStyle(strokeColor: .systemOrange),
            .sar: LineStyle(strokeColor: .systemOrange),
            .bbi: LineStyle(strokeColor: .systemPurple),
            .vwma(period: 20): LineStyle(strokeColor: .systemBrown),
            .donchian(period: 20): LineStyle(strokeColor: .systemGreen),
            .superTrend(period: 10, multiplier: 3): SuperTrendStyle(
                upColor: UIColor(red: 0.16, green: 0.50, blue: 0.96, alpha: 1),
                downColor: UIColor(red: 1.0, green: 0.58, blue: 0.04, alpha: 1)
            ),
            .ichimoku(tenkanPeriod: 9, kijunPeriod: 26, senkouBPeriod: 52, displacement: 26): IchimokuStyle(
                tenkanColor: .systemOrange,
                kijunColor: .systemBlue,
                spanAColor: .systemGreen,
                spanBColor: .systemRed,
                chikouColor: .systemPurple,
                bullishCloudColor: UIColor.systemGreen.withAlphaComponent(0.12),
                bearishCloudColor: UIColor.systemRed.withAlphaComponent(0.12)
            ),
            .rsi(period: 6): LineStyle(strokeColor: .systemOrange),
            .rsi(period: 12): LineStyle(strokeColor: .systemPink),
            .rsi(period: 24): LineStyle(strokeColor: .systemTeal),
            .macd(shortPeriod: 12, longPeriod: 26, signalPeriod: 9): MACDStyle(macdColor: .systemOrange, difColor: .systemPink, deaColor: .systemTeal)
        ]
    }
}

public extension ChartAppearance {

    /// A reusable visual preset, independent of indicator selection and provider behavior.
    ///
    /// The preset contains appearance and layout values, not a data source or mutable chart state.
    struct ThemePreset {
        /// The candle appearance supplied by this preset.
        public var candleStyle: CandleStyle
        /// The legend font supplied by this preset.
        public var legendFont: UIFont
        /// Optional watermark text supplied by this preset.
        public var watermarkText: String?
        /// The section heights supplied by this preset.
        public var layout: LayoutMetrics
        /// The complete series-keyed style map supplied by this preset.
        public var indicatorStyles: [SeriesKey: any IndicatorStyle]

        /// Creates an appearance preset; nil indicatorStyles selects the built-in default style map.
        public init(
            candleStyle: CandleStyle,
            legendFont: UIFont = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            watermarkText: String?,
            layout: LayoutMetrics = LayoutMetrics(),
            indicatorStyles: [SeriesKey: any IndicatorStyle]? = nil
        ) {
            self.candleStyle = candleStyle
            self.legendFont = legendFont
            self.watermarkText = watermarkText
            self.layout = layout
            self.indicatorStyles = indicatorStyles ?? ChartAppearance.makeDefaultIndicatorStyles()
        }
    }

    /// Creates a configuration from a preset with standard indicator availability and empty selection defaults.
    static func themed(_ preset: ThemePreset) -> ChartAppearance {
        ChartAppearance(
            candleStyle: preset.candleStyle,
            legendFont: preset.legendFont,
            watermarkText: preset.watermarkText,
            layoutMetrics: preset.layout,
            indicatorStyleRegistry: preset.indicatorStyles
        )
    }
}

public extension ChartAppearance.ThemePreset {

    /// A vivid preset intended for dark presentations; the container controls its background and interface style.
    static var midnight: ChartAppearance.ThemePreset {
        let candle = CandleStyle(
            risingColor: UIColor(red: 0.12, green: 0.84, blue: 0.72, alpha: 1),
            fallingColor: UIColor(red: 0.96, green: 0.32, blue: 0.48, alpha: 1),
            width: 9,
            gap: 2
        )
        let layout = LayoutMetrics(
            mainChartHeight: 340,
            timelineHeight: 18,
            indicatorHeight: 76,
            indicatorSelectorHeight: 36
        )
        let indicatorStyles: [SeriesKey: any IndicatorStyle] = [
            .ma(period: 5): LineStyle(strokeColor: UIColor(red: 1, green: 0.78, blue: 0.32, alpha: 1)),
            .ma(period: 10): LineStyle(strokeColor: UIColor(red: 0.97, green: 0.5, blue: 0.67, alpha: 1)),
            .ma(period: 20): LineStyle(strokeColor: UIColor(red: 0.4, green: 0.85, blue: 1, alpha: 1)),
            .ema(period: 5): LineStyle(strokeColor: UIColor(red: 0.92, green: 0.68, blue: 1, alpha: 1)),
            .ema(period: 10): LineStyle(strokeColor: UIColor(red: 0.47, green: 0.87, blue: 0.98, alpha: 1)),
            .ema(period: 20): LineStyle(strokeColor: UIColor(red: 0.32, green: 0.71, blue: 1, alpha: 1)),
            .wma(period: 5): LineStyle(strokeColor: UIColor(red: 0.63, green: 0.89, blue: 0.75, alpha: 1)),
            .wma(period: 10): LineStyle(strokeColor: UIColor(red: 0.74, green: 0.8, blue: 0.98, alpha: 1)),
            .wma(period: 20): LineStyle(strokeColor: UIColor(red: 0.97, green: 0.84, blue: 0.96, alpha: 1)),
            .boll(period: 20, k: 2.0): LineStyle(strokeColor: UIColor(red: 0.64, green: 0.78, blue: 1, alpha: 1)),
            .sar: LineStyle(strokeColor: UIColor(red: 1, green: 0.71, blue: 0.45, alpha: 1)),
            .bbi: LineStyle(strokeColor: UIColor(red: 0.82, green: 0.66, blue: 1, alpha: 1)),
            .vwma(period: 20): LineStyle(strokeColor: UIColor(red: 0.95, green: 0.76, blue: 0.53, alpha: 1)),
            .donchian(period: 20): LineStyle(strokeColor: UIColor(red: 0.53, green: 0.9, blue: 0.7, alpha: 1)),
            .superTrend(period: 10, multiplier: 3): SuperTrendStyle(
                upColor: UIColor(red: 0.33, green: 0.68, blue: 1, alpha: 1),
                downColor: UIColor(red: 1, green: 0.63, blue: 0.10, alpha: 1)
            ),
            .ichimoku(tenkanPeriod: 9, kijunPeriod: 26, senkouBPeriod: 52, displacement: 26): IchimokuStyle(
                tenkanColor: UIColor(red: 1, green: 0.78, blue: 0.32, alpha: 1),
                kijunColor: UIColor(red: 0.4, green: 0.85, blue: 1, alpha: 1),
                spanAColor: UIColor(red: 0.53, green: 0.9, blue: 0.7, alpha: 1),
                spanBColor: UIColor(red: 0.97, green: 0.5, blue: 0.67, alpha: 1),
                chikouColor: UIColor(red: 0.82, green: 0.66, blue: 1, alpha: 1),
                bullishCloudColor: UIColor(red: 0.12, green: 0.84, blue: 0.72, alpha: 0.14),
                bearishCloudColor: UIColor(red: 0.96, green: 0.32, blue: 0.48, alpha: 0.12)
            ),
            .rsi(period: 6): LineStyle(strokeColor: UIColor(red: 0.83, green: 0.93, blue: 1, alpha: 1)),
            .rsi(period: 12): LineStyle(strokeColor: UIColor(red: 1, green: 0.77, blue: 0.53, alpha: 1)),
            .rsi(period: 24): LineStyle(strokeColor: UIColor(red: 0.58, green: 0.89, blue: 0.71, alpha: 1)),
            .macd(shortPeriod: 12, longPeriod: 26, signalPeriod: 9): MACDStyle(
                macdColor: UIColor(red: 0.97, green: 0.69, blue: 0.36, alpha: 1),
                difColor: UIColor(red: 0.63, green: 0.89, blue: 1, alpha: 1),
                deaColor: UIColor(red: 1, green: 0.47, blue: 0.64, alpha: 1)
            )
        ]
        return ChartAppearance.ThemePreset(
            candleStyle: candle,
            legendFont: UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            watermarkText: "SwiftKLine • Midnight",
            layout: layout,
            indicatorStyles: indicatorStyles
        )
    }

    /// A warm preset intended for light presentations; the container controls its background and interface style.
    static var solaris: ChartAppearance.ThemePreset {
        let candle = CandleStyle(
            risingColor: UIColor(red: 0.98, green: 0.72, blue: 0.18, alpha: 1),
            fallingColor: UIColor(red: 0.20, green: 0.27, blue: 0.38, alpha: 1),
            width: 9,
            gap: 2.4
        )
        let layout = LayoutMetrics(
            mainChartHeight: 320,
            timelineHeight: 16,
            indicatorHeight: 70,
            indicatorSelectorHeight: 34
        )
        let indicatorStyles: [SeriesKey: any IndicatorStyle] = [
            .ma(period: 5): LineStyle(strokeColor: UIColor(red: 0.98, green: 0.72, blue: 0.18, alpha: 1)),
            .ma(period: 10): LineStyle(strokeColor: UIColor(red: 0.44, green: 0.63, blue: 0.85, alpha: 1)),
            .ma(period: 20): LineStyle(strokeColor: UIColor(red: 0.67, green: 0.76, blue: 0.83, alpha: 1)),
            .ema(period: 5): LineStyle(strokeColor: UIColor(red: 0.98, green: 0.50, blue: 0.15, alpha: 1)),
            .ema(period: 10): LineStyle(strokeColor: UIColor(red: 0.36, green: 0.68, blue: 0.91, alpha: 1)),
            .ema(period: 20): LineStyle(strokeColor: UIColor(red: 0.18, green: 0.35, blue: 0.55, alpha: 1)),
            .wma(period: 5): LineStyle(strokeColor: UIColor(red: 0.84, green: 0.58, blue: 0.28, alpha: 1)),
            .wma(period: 10): LineStyle(strokeColor: UIColor(red: 0.25, green: 0.55, blue: 0.70, alpha: 1)),
            .wma(period: 20): LineStyle(strokeColor: UIColor(red: 0.61, green: 0.63, blue: 0.54, alpha: 1)),
            .boll(period: 20, k: 2.0): LineStyle(strokeColor: UIColor(red: 0.95, green: 0.89, blue: 0.75, alpha: 1)),
            .sar: LineStyle(strokeColor: UIColor(red: 0.20, green: 0.27, blue: 0.38, alpha: 1)),
            .bbi: LineStyle(strokeColor: UIColor(red: 0.55, green: 0.36, blue: 0.74, alpha: 1)),
            .vwma(period: 20): LineStyle(strokeColor: UIColor(red: 0.63, green: 0.45, blue: 0.24, alpha: 1)),
            .donchian(period: 20): LineStyle(strokeColor: UIColor(red: 0.3, green: 0.6, blue: 0.45, alpha: 1)),
            .superTrend(period: 10, multiplier: 3): SuperTrendStyle(
                upColor: UIColor(red: 0.22, green: 0.53, blue: 0.88, alpha: 1),
                downColor: UIColor(red: 0.91, green: 0.52, blue: 0.12, alpha: 1)
            ),
            .ichimoku(tenkanPeriod: 9, kijunPeriod: 26, senkouBPeriod: 52, displacement: 26): IchimokuStyle(
                tenkanColor: UIColor(red: 0.98, green: 0.50, blue: 0.15, alpha: 1),
                kijunColor: UIColor(red: 0.36, green: 0.68, blue: 0.91, alpha: 1),
                spanAColor: UIColor(red: 0.30, green: 0.60, blue: 0.45, alpha: 1),
                spanBColor: UIColor(red: 0.78, green: 0.45, blue: 0.42, alpha: 1),
                chikouColor: UIColor(red: 0.55, green: 0.36, blue: 0.74, alpha: 1),
                bullishCloudColor: UIColor(red: 0.30, green: 0.60, blue: 0.45, alpha: 0.12),
                bearishCloudColor: UIColor(red: 0.78, green: 0.45, blue: 0.42, alpha: 0.10)
            ),
            .rsi(period: 6): LineStyle(strokeColor: UIColor(red: 0.98, green: 0.72, blue: 0.18, alpha: 1)),
            .rsi(period: 12): LineStyle(strokeColor: UIColor(red: 0.36, green: 0.68, blue: 0.91, alpha: 1)),
            .rsi(period: 24): LineStyle(strokeColor: UIColor(red: 0.79, green: 0.68, blue: 0.75, alpha: 1)),
            .macd(shortPeriod: 12, longPeriod: 26, signalPeriod: 9): MACDStyle(
                macdColor: UIColor(red: 0.98, green: 0.50, blue: 0.15, alpha: 1),
                difColor: UIColor(red: 0.36, green: 0.68, blue: 0.91, alpha: 1),
                deaColor: UIColor(red: 0.20, green: 0.27, blue: 0.38, alpha: 1)
            )
        ]
        return ChartAppearance.ThemePreset(
            candleStyle: candle,
            legendFont: UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            watermarkText: "SwiftKLine • Solaris",
            layout: layout,
            indicatorStyles: indicatorStyles
        )
    }
}