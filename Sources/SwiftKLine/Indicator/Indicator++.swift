//
//  SwiftKLine.swift
//  SwiftKLine
//
//  Created by W Zh on 2025/7/26.
//

import Foundation

extension Indicator {
    
    @MainActor func makeCalculators(configuration: KLineConfiguration) -> [any IndicatorCalculator] {
        configuration.indicatorKeys(for: self).compactMap { key in
            switch key {
            case .vol:              return VOLCalculator()
            case let .ma(period):   return MACalculator(period: period)
            case let .ema(period):  return EMACalculator(period: period)
            case let .wma(period):  return WMACalculator(period: period)
            case .boll:             return BOLLCalculator()
            case .sar:              return SARCalculator()
            case let .rsi(period):  return RSICalculator(period: period)
            case let .macd:         return MACDCalculator()
            }
        }
    }
}
