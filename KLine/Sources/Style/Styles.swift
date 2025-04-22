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
    
    public var candleStyle = CandleStyle()
    public var priceFractionDigits: Int = 4
    
//    private var indicatorStyles: [Indicator.Key: IndicatorStyle] = [
//        
//        .ma(period: 5): TrackStyle(strokeColor: .systemOrange),
//        .ma(period: 10): TrackStyle(strokeColor: .systemPink),
//        .ma(period: 20): TrackStyle(strokeColor: .systemTeal),
//        
//        .ema(period: 5): TrackStyle(strokeColor: .systemOrange),
//        .ema(period: 10): TrackStyle(strokeColor: .systemPink),
//        .ema(period: 20): TrackStyle(strokeColor: .systemTeal),
//        
//        .rsi(period: 6): TrackStyle(strokeColor: .systemOrange),
//        .rsi(period: 12): TrackStyle(strokeColor: .systemPink),
//        .rsi(period: 24): TrackStyle(strokeColor: .systemTeal),
//        
//        .macd(shortPeriod: 12, longPeriod: 26, signalPeriod: 9): MACDStyle(macdColor: .systemOrange, difColor: .systemPink, deaColor: .systemTeal)
//    ]
//        
//    public func setIndicatorStyle<S>(_ style: S, for key: Indicator.Key) where S: IndicatorStyle {
//        indicatorStyles[key] = style
//    }
//    
//    public func indicatorStyle<S>(for key: Indicator.Key, type: S.Type) -> S? where S: IndicatorStyle {
//        let style = indicatorStyles[key]
//        return style as? S
//    }
}
