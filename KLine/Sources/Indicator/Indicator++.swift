//
//  File.swift
//  KLine
//
//  Created by W Zh on 2025/7/26.
//

import Foundation

extension Indicator {
    
    @MainActor
    func makeRenderer() -> any Renderer {
        switch self {
        case .vol:
            return VOLRenderer()
        case .ma:
            return MARenderer(configurations: [
                MARenderer.Configuration(period: 5, style: LineStyle(strokeColor: .systemOrange)),
                MARenderer.Configuration(period: 10, style: LineStyle(strokeColor: .systemPink)),
                MARenderer.Configuration(period: 20, style: LineStyle(strokeColor: .systemTeal))
            ])
        case .ema:
            return EMARenderer(configurations: [
                EMARenderer.Configuration(period: 5, style: LineStyle(strokeColor: .systemOrange)),
                EMARenderer.Configuration(period: 10, style: LineStyle(strokeColor: .systemPink)),
                EMARenderer.Configuration(period: 20, style: LineStyle(strokeColor: .systemTeal))
            ])
        case .rsi:
            return RSIRenderer(configurations: [
                RSIRenderer.Configuration(period: 5, style: LineStyle(strokeColor: .systemOrange)),
                RSIRenderer.Configuration(period: 10, style: LineStyle(strokeColor: .systemPink)),
                RSIRenderer.Configuration(period: 20, style: LineStyle(strokeColor: .systemTeal))
            ])
        case .macd:
            return MACDRenderer(
                configuration: MACDRenderer.Configuration(
                    shortPeriod: 12,
                    longPeriod: 26,
                    signalPeriod: 9,
                    style: MACDStyle(
                        macdColor: .systemOrange,
                        difColor: .systemPink,
                        deaColor: .systemTeal
                    )
                )
            )
        }
    }
}

extension Indicator {
    
    func makeCalculators() -> [any IndicatorCalculator] {
        switch self {
        case .vol: return [
            VOLCalculator()
        ]
        case .ma: return [
            MACalculator(period: 5),
            MACalculator(period: 10),
            MACalculator(period: 20)
        ]
        case .ema: return [
            EMACalculator(period: 5),
            EMACalculator(period: 10),
            EMACalculator(period: 20)
        ]
        case .rsi: return [
            RSICalculator(period: 5),
            RSICalculator(period: 10),
            RSICalculator(period: 20)
        ]
        case .macd: return [
            MACDCalculator(shortPeriod: 12, longPeriod: 26, signalPeriod: 9)
        ]
        }
    }
}
