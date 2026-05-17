import UIKit

public struct ChartConfiguration {

    public let candleStyle: CandleStyle
    public let legendFont: UIFont
    public let watermarkText: String?
    public let layoutMetrics: LayoutMetrics
    public let indicators: [BuiltInIndicator]
    public let defaultMainIndicators: [BuiltInIndicator]
    public let defaultSubIndicators: [BuiltInIndicator]

    private var indicatorStyleRegistry: [SeriesKey: any IndicatorStyle]
    private var indicatorKeyOverrides: [BuiltInIndicator: [SeriesKey]]

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

    public func indicatorStyle<S>(for key: SeriesKey, type: S.Type) -> S? where S: IndicatorStyle {
        indicatorStyleRegistry[key] as? S
    }

    public func indicatorKeys(for indicator: BuiltInIndicator) -> [SeriesKey] {
        indicatorKeyOverrides[indicator] ?? indicator.defaultSeriesKeys
    }

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
            .rsi(period: 6): LineStyle(strokeColor: .systemOrange),
            .rsi(period: 12): LineStyle(strokeColor: .systemPink),
            .rsi(period: 24): LineStyle(strokeColor: .systemTeal),
            .macd(shortPeriod: 12, longPeriod: 26, signalPeriod: 9): MACDStyle(macdColor: .systemOrange, difColor: .systemPink, deaColor: .systemTeal)
        ]
    }
}

public extension ChartConfiguration {

    struct ThemePreset {
        public var candleStyle: CandleStyle
        public var legendFont: UIFont
        public var watermarkText: String?
        public var layout: LayoutMetrics
        public var indicatorStyles: [SeriesKey: any IndicatorStyle]

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
            self.indicatorStyles = indicatorStyles ?? ChartConfiguration.makeDefaultIndicatorStyles()
        }
    }

    static func themed(_ preset: ThemePreset) -> ChartConfiguration {
        ChartConfiguration(
            candleStyle: preset.candleStyle,
            legendFont: preset.legendFont,
            watermarkText: preset.watermarkText,
            layoutMetrics: preset.layout,
            indicatorStyleRegistry: preset.indicatorStyles
        )
    }
}

public extension ChartConfiguration.ThemePreset {

    static var midnight: ChartConfiguration.ThemePreset {
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
            .rsi(period: 6): LineStyle(strokeColor: UIColor(red: 0.83, green: 0.93, blue: 1, alpha: 1)),
            .rsi(period: 12): LineStyle(strokeColor: UIColor(red: 1, green: 0.77, blue: 0.53, alpha: 1)),
            .rsi(period: 24): LineStyle(strokeColor: UIColor(red: 0.58, green: 0.89, blue: 0.71, alpha: 1)),
            .macd(shortPeriod: 12, longPeriod: 26, signalPeriod: 9): MACDStyle(
                macdColor: UIColor(red: 0.97, green: 0.69, blue: 0.36, alpha: 1),
                difColor: UIColor(red: 0.63, green: 0.89, blue: 1, alpha: 1),
                deaColor: UIColor(red: 1, green: 0.47, blue: 0.64, alpha: 1)
            )
        ]
        return ChartConfiguration.ThemePreset(
            candleStyle: candle,
            legendFont: UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            watermarkText: "SwiftKLine • Midnight",
            layout: layout,
            indicatorStyles: indicatorStyles
        )
    }

    static var solaris: ChartConfiguration.ThemePreset {
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
            .rsi(period: 6): LineStyle(strokeColor: UIColor(red: 0.98, green: 0.72, blue: 0.18, alpha: 1)),
            .rsi(period: 12): LineStyle(strokeColor: UIColor(red: 0.36, green: 0.68, blue: 0.91, alpha: 1)),
            .rsi(period: 24): LineStyle(strokeColor: UIColor(red: 0.79, green: 0.68, blue: 0.75, alpha: 1)),
            .macd(shortPeriod: 12, longPeriod: 26, signalPeriod: 9): MACDStyle(
                macdColor: UIColor(red: 0.98, green: 0.50, blue: 0.15, alpha: 1),
                difColor: UIColor(red: 0.36, green: 0.68, blue: 0.91, alpha: 1),
                deaColor: UIColor(red: 0.20, green: 0.27, blue: 0.38, alpha: 1)
            )
        ]
        return ChartConfiguration.ThemePreset(
            candleStyle: candle,
            legendFont: UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            watermarkText: "SwiftKLine • Solaris",
            layout: layout,
            indicatorStyles: indicatorStyles
        )
    }
}