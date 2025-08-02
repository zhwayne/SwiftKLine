//
//  KLineConfig.swift
//  KLine
//
//  Created by iya on 2024/11/1.
//

import UIKit

@MainActor public struct CandleStyle {
    public var risingColor: UIColor = .systemTeal
    public var fallingColor: UIColor = .systemPink
    public var width: CGFloat = 10
    public var gap: CGFloat = 2
    
    fileprivate init() { }
}

@MainActor final public class KLineConfig {
    
    public static let `default` = KLineConfig()
    
    private init() { }
    
    private var indicatorStyleRegistry: [Indicator.Key: any IndicatorStyle] = [
        // MA
        .ma(5): LineStyle(strokeColor: .systemOrange),
        .ma(10): LineStyle(strokeColor: .systemPink),
        .ma(20): LineStyle(strokeColor: .systemTeal),
        // EMA
        .ema(5): LineStyle(strokeColor: .systemOrange),
        .ema(10): LineStyle(strokeColor: .systemPink),
        .ema(20): LineStyle(strokeColor: .systemTeal),
        // RSI
        .rsi(6): LineStyle(strokeColor: .systemOrange),
        .rsi(12): LineStyle(strokeColor: .systemPink),
        .rsi(24): LineStyle(strokeColor: .systemTeal),
        // MACD
        .macd: MACDStyle(macdColor: .systemOrange, difColor: .systemPink, deaColor: .systemTeal)
    ]
    
    public func setIndicatorStyle<S>(_ style: S, for key: Indicator.Key) where S: IndicatorStyle {
        indicatorStyleRegistry[key] = style
    }
    
    public func indicatorStyle<S>(for key: Indicator.Key, type: S.Type) -> S? where S: IndicatorStyle {
        let style = indicatorStyleRegistry[key]
        return style as? S
    }
    
    public var candleStyle = CandleStyle()
    public var legendFont: UIFont { UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular) }
    
    public var indicators: [Indicator] = Indicator.allCases
}
