//
//  Styles.swift
//  KLine
//
//  Created by iya on 2024/11/1.
//

import UIKit

public struct CandleStyle {
    public var risingColor: UIColor = .systemTeal
    public var fallingColor: UIColor = .systemPink
    public var width: CGFloat = 10
    public var gap: CGFloat = 2
    
    fileprivate init() { }
}

final public class StyleManager {
    
    nonisolated(unsafe) public static let shared = StyleManager()
    
    private init() { }
    
//    private var indicatorStyleRegistry: [Indicator.Key: any IndicatorStyle] = [
//        // MA
//        .ma(period: 5): LineStyle(strokeColor: .systemOrange),
//        .ma(period: 10): LineStyle(strokeColor: .systemPink),
//        .ma(period: 20): LineStyle(strokeColor: .systemTeal),
//        // EMA
//        .ema(period: 5): LineStyle(strokeColor: .systemOrange),
//        .ema(period: 10): LineStyle(strokeColor: .systemPink),
//        .ema(period: 20): LineStyle(strokeColor: .systemTeal),
//        // RSI
//        .rsi(period: 6): LineStyle(strokeColor: .systemOrange),
//        .rsi(period: 12): LineStyle(strokeColor: .systemPink),
//        .rsi(period: 24): LineStyle(strokeColor: .systemTeal),
//        // MACD
//        .macd(shortPeriod: 12, longPeriod: 26, signalPeriod: 9): MACDStyle(macdColor: .systemOrange, difColor: .systemPink, deaColor: .systemTeal)
//    ]
//    
//    public func setIndicatorStyle<S>(_ style: S, for key: Indicator.Key) where S: IndicatorStyle {
//        indicatorStyleRegistry[key] = style
//    }
//    
//    public func indicatorStyle<S>(for key: Indicator.Key, type: S.Type) -> S? where S: IndicatorStyle {
//        let style = indicatorStyleRegistry[key]
//        return style as? S
//    }
//    
    public var candleStyle = CandleStyle()
    public var legendFont: UIFont { UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular) }
}
