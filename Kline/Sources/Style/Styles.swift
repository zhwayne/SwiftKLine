//
//  Styles.swift
//  KLineDemo
//
//  Created by iya on 2024/11/1.
//

import UIKit

public struct IndicatorStyle {
    fileprivate(set) var candleStyle: CandleStyle?
    
    public let strokeColor: UIColor
    public let lineWidth: CGFloat
    public let fillColor: UIColor
    public let font: UIFont
    
    public init(
        strokeColor: UIColor,
        lineWidth: CGFloat = 1,
        fillColor: UIColor = UIColor.clear,
        font: UIFont = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
    ) {
        self.strokeColor = strokeColor
        self.lineWidth = lineWidth
        self.fillColor = fillColor
        self.font = font
    }
}

public struct CandleStyle {
    public var upColor: UIColor = .systemTeal
    public var downColor: UIColor = .systemPink
    public var width: CGFloat = 12
    public var gap: CGFloat = 2
        
    fileprivate init() { }
}

final public class StyleManager {
    
    nonisolated(unsafe) public static let shared = StyleManager()
        
    private init() { }
    
    public var candleStyle = CandleStyle()
    public var priceFractionDigits: Int = 4
    
    private var indicatorStyles: [IndicatorKey: IndicatorStyle] = [
        .vol: .init(strokeColor: UIColor.secondaryLabel),
        
        .ma(period: 5): .init(strokeColor: .systemOrange),
        .ma(period: 10): .init(strokeColor: .systemPink),
        .ma(period: 20): .init(strokeColor: .systemTeal),
        
        .ema(period: 5): .init(strokeColor: .systemOrange),
        .ema(period: 10): .init(strokeColor: .systemPink),
        .ema(period: 20): .init(strokeColor: .systemTeal),
        
        .rsi(period: 6): .init(strokeColor: .systemOrange),
        .rsi(period: 12): .init(strokeColor: .systemPink),
        .rsi(period: 24): .init(strokeColor: .systemTeal)
    ]
    
    public func setIndicatorStyle(_ style: IndicatorStyle, for key: IndicatorKey) {
        indicatorStyles[key] = style
    }
    
    public func indicatorStyle(for key: IndicatorKey) -> IndicatorStyle {
        var style = indicatorStyles[key] ?? IndicatorStyle(strokeColor: .label)
        style.candleStyle = candleStyle
        return style
    }
}
