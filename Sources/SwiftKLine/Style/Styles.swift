//
//  KLineConfig.swift
//  SwiftKLine
//
//  Created by iya on 2024/11/1.
//

import UIKit

@MainActor public struct CandleStyle {
    public let risingColor: UIColor
    public let fallingColor: UIColor
    public internal(set) var width: CGFloat
    public internal(set) var gap: CGFloat
    
    public init(
        risingColor: UIColor = .systemTeal,
        fallingColor: UIColor = .systemPink,
        width: CGFloat = 10,
        gap: CGFloat = 2
    ) {
        self.risingColor = risingColor
        self.fallingColor = fallingColor
        self.width = width
        self.gap = gap
    }
}

@MainActor public struct LayoutMetrics {
    public let mainChartHeight: CGFloat
    public let timelineHeight: CGFloat
    public let indicatorHeight: CGFloat
    public let indicatorSelectorHeight: CGFloat
    
    public init(
        mainChartHeight: CGFloat = 320,
        timelineHeight: CGFloat = 16,
        indicatorHeight: CGFloat = 64,
        indicatorSelectorHeight: CGFloat = 32
    ) {
        self.mainChartHeight = mainChartHeight
        self.timelineHeight = timelineHeight
        self.indicatorHeight = indicatorHeight
        self.indicatorSelectorHeight = indicatorSelectorHeight
    }
}

@MainActor public final class KLineConfiguration {
    
    @available(*, deprecated, message: "请在视图初始化时注入自定义配置，而不是访问全局单例。")
    public static let `default` = KLineConfiguration()
    
    public static func standard() -> KLineConfiguration {
        KLineConfiguration()
    }
    
    public internal(set) var candleStyle: CandleStyle
    public let legendFont: UIFont
    public let watermarkText: String?
    public let indicators: [Indicator]
    public let defaultMainIndicators: [Indicator]
    public let defaultSubIndicators: [Indicator]
    public let layoutMetrics: LayoutMetrics
    
    private var indicatorStyleRegistry: [Indicator.Key: any IndicatorStyle]
    private var indicatorKeyOverrides: [Indicator: [Indicator.Key]]
    
    public init(
        candleStyle: CandleStyle = CandleStyle(),
        legendFont: UIFont = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
        watermarkText: String? = "Created by iyabb",
        indicators: [Indicator] = Indicator.allCases,
        defaultMainIndicators: [Indicator] = [.ma, .boll],
        defaultSubIndicators: [Indicator] = [.macd, .vol],
        layoutMetrics: LayoutMetrics = LayoutMetrics(),
        indicatorStyleRegistry: [Indicator.Key: any IndicatorStyle]? = nil,
        indicatorKeyOverrides: [Indicator: [Indicator.Key]] = [:]
    ) {
        self.candleStyle = candleStyle
        self.legendFont = legendFont
        self.watermarkText = watermarkText
        self.indicators = indicators
        self.defaultMainIndicators = defaultMainIndicators
        self.defaultSubIndicators = defaultSubIndicators
        self.layoutMetrics = layoutMetrics
        self.indicatorStyleRegistry = indicatorStyleRegistry ?? Self.makeDefaultIndicatorStyles()
        self.indicatorKeyOverrides = indicatorKeyOverrides
    }
    
    public convenience init(_ builder: (KLineConfiguration) -> Void) {
        self.init()
        builder(self)
    }
    
    public func setIndicatorStyle<S>(_ style: S, for key: Indicator.Key) where S: IndicatorStyle {
        //objectWillChange.send()
        indicatorStyleRegistry[key] = style
    }
    
    public func indicatorStyle<S>(for key: Indicator.Key, type: S.Type) -> S? where S: IndicatorStyle {
        indicatorStyleRegistry[key] as? S
    }
    
    public func setIndicatorKeys(_ keys: [Indicator.Key], for indicator: Indicator) {
        //objectWillChange.send()
        if keys.isEmpty {
            indicatorKeyOverrides[indicator] = nil
        } else {
            indicatorKeyOverrides[indicator] = keys
        }
    }
    
    public func indicatorKeys(for indicator: Indicator) -> [Indicator.Key] {
        indicatorKeyOverrides[indicator] ?? indicator.defaultKeys
    }
    
    static func makeDefaultIndicatorStyles() -> [Indicator.Key: any IndicatorStyle] {
        [
            // MA
            .ma(5): LineStyle(strokeColor: .systemOrange),
            .ma(10): LineStyle(strokeColor: .systemPink),
            .ma(20): LineStyle(strokeColor: .systemTeal),
            // EMA
            .ema(5): LineStyle(strokeColor: .systemOrange),
            .ema(10): LineStyle(strokeColor: .systemPink),
            .ema(20): LineStyle(strokeColor: .systemTeal),
            // BOLL
            .boll: LineStyle(strokeColor: .systemOrange),
            // SAR
            .sar: LineStyle(strokeColor: .systemOrange),
            // RSI
            .rsi(6): LineStyle(strokeColor: .systemOrange),
            .rsi(12): LineStyle(strokeColor: .systemPink),
            .rsi(24): LineStyle(strokeColor: .systemTeal),
            // MACD
            .macd: MACDStyle(macdColor: .systemOrange, difColor: .systemPink, deaColor: .systemTeal)
        ]
    }
}

@MainActor
public extension KLineConfiguration {
    
    @MainActor public struct ThemePreset {
        public var candleStyle: CandleStyle
        public var legendFont: UIFont
        public var watermarkText: String?
        public var layout: LayoutMetrics
        public var indicatorStyles: [Indicator.Key: any IndicatorStyle]
        
        public init(
            candleStyle: CandleStyle,
            legendFont: UIFont = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            watermarkText: String?,
            layout: LayoutMetrics = LayoutMetrics(),
            indicatorStyles: [Indicator.Key: any IndicatorStyle]? = nil
        ) {
            self.candleStyle = candleStyle
            self.legendFont = legendFont
            self.watermarkText = watermarkText
            self.layout = layout
            self.indicatorStyles = indicatorStyles ?? KLineConfiguration.makeDefaultIndicatorStyles()
        }
    }
    
    static func themed(_ preset: ThemePreset) -> KLineConfiguration {
        KLineConfiguration(
            candleStyle: preset.candleStyle,
            legendFont: preset.legendFont,
            watermarkText: preset.watermarkText,
            layoutMetrics: preset.layout,
            indicatorStyleRegistry: preset.indicatorStyles
        )
    }
}

public extension KLineConfiguration.ThemePreset {
    
    static var midnight: KLineConfiguration.ThemePreset {
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
        let indicatorStyles: [Indicator.Key: any IndicatorStyle] = [
            .ma(5): LineStyle(strokeColor: UIColor(red: 1, green: 0.78, blue: 0.32, alpha: 1)),
            .ma(10): LineStyle(strokeColor: UIColor(red: 0.97, green: 0.5, blue: 0.67, alpha: 1)),
            .ma(20): LineStyle(strokeColor: UIColor(red: 0.4, green: 0.85, blue: 1, alpha: 1)),
            .ema(5): LineStyle(strokeColor: UIColor(red: 0.92, green: 0.68, blue: 1, alpha: 1)),
            .ema(10): LineStyle(strokeColor: UIColor(red: 0.47, green: 0.87, blue: 0.98, alpha: 1)),
            .ema(20): LineStyle(strokeColor: UIColor(red: 0.32, green: 0.71, blue: 1, alpha: 1)),
            .boll: LineStyle(strokeColor: UIColor(red: 0.64, green: 0.78, blue: 1, alpha: 1)),
            .sar: LineStyle(strokeColor: UIColor(red: 1, green: 0.71, blue: 0.45, alpha: 1)),
            .rsi(6): LineStyle(strokeColor: UIColor(red: 0.83, green: 0.93, blue: 1, alpha: 1)),
            .rsi(12): LineStyle(strokeColor: UIColor(red: 1, green: 0.77, blue: 0.53, alpha: 1)),
            .rsi(24): LineStyle(strokeColor: UIColor(red: 0.58, green: 0.89, blue: 0.71, alpha: 1)),
            .macd: MACDStyle(
                macdColor: UIColor(red: 0.97, green: 0.69, blue: 0.36, alpha: 1),
                difColor: UIColor(red: 0.63, green: 0.89, blue: 1, alpha: 1),
                deaColor: UIColor(red: 1, green: 0.47, blue: 0.64, alpha: 1)
            )
        ]
        return KLineConfiguration.ThemePreset(
            candleStyle: candle,
            legendFont: UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            watermarkText: "SwiftKLine • Midnight",
            layout: layout,
            indicatorStyles: indicatorStyles
        )
    }
    
    static var solaris: KLineConfiguration.ThemePreset {
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
        let indicatorStyles: [Indicator.Key: any IndicatorStyle] = [
            .ma(5): LineStyle(strokeColor: UIColor(red: 0.98, green: 0.72, blue: 0.18, alpha: 1)),
            .ma(10): LineStyle(strokeColor: UIColor(red: 0.44, green: 0.63, blue: 0.85, alpha: 1)),
            .ma(20): LineStyle(strokeColor: UIColor(red: 0.67, green: 0.76, blue: 0.83, alpha: 1)),
            .ema(5): LineStyle(strokeColor: UIColor(red: 0.98, green: 0.50, blue: 0.15, alpha: 1)),
            .ema(10): LineStyle(strokeColor: UIColor(red: 0.36, green: 0.68, blue: 0.91, alpha: 1)),
            .ema(20): LineStyle(strokeColor: UIColor(red: 0.18, green: 0.35, blue: 0.55, alpha: 1)),
            .boll: LineStyle(strokeColor: UIColor(red: 0.95, green: 0.89, blue: 0.75, alpha: 1)),
            .sar: LineStyle(strokeColor: UIColor(red: 0.20, green: 0.27, blue: 0.38, alpha: 1)),
            .rsi(6): LineStyle(strokeColor: UIColor(red: 0.98, green: 0.72, blue: 0.18, alpha: 1)),
            .rsi(12): LineStyle(strokeColor: UIColor(red: 0.36, green: 0.68, blue: 0.91, alpha: 1)),
            .rsi(24): LineStyle(strokeColor: UIColor(red: 0.79, green: 0.68, blue: 0.75, alpha: 1)),
            .macd: MACDStyle(
                macdColor: UIColor(red: 0.98, green: 0.50, blue: 0.15, alpha: 1),
                difColor: UIColor(red: 0.36, green: 0.68, blue: 0.91, alpha: 1),
                deaColor: UIColor(red: 0.20, green: 0.27, blue: 0.38, alpha: 1)
            )
        ]
        return KLineConfiguration.ThemePreset(
            candleStyle: candle,
            legendFont: UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            watermarkText: "SwiftKLine • Solaris",
            layout: layout,
            indicatorStyles: indicatorStyles
        )
    }
}
