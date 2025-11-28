//
//  IndicatorRendererRegistry.swift
//  SwiftKLine
//
//  Created by W Zh on 2025/11/13.
//

import Foundation

@MainActor
final class IndicatorRendererRegistry {
    typealias Provider = (Indicator, KLineConfiguration) -> (any Renderer)?
    
    static let shared = IndicatorRendererRegistry()
    private var providers: [Indicator: [Provider]] = [:]
    
    private init() {
        registerDefaultRenderers()
    }
    
    func register(for indicator: Indicator, provider: @escaping Provider) {
        providers[indicator, default: []].append(provider)
    }
    
    func renderers(for indicator: Indicator, configuration: KLineConfiguration) -> [AnyRenderer] {
        guard let registeredProviders = providers[indicator] else { return [] }
        return registeredProviders.compactMap { provider in
            guard let renderer = provider(indicator, configuration) else { return nil }
            return renderer.eraseToAnyRenderer()
        }
    }
}


extension IndicatorRendererRegistry {
    
    private func registerDefaultRenderers() {
        register(for: .ma) { indicator, configuration in
            let periods = configuration.indicatorKeys(for: indicator).compactMap { key -> Int? in
                guard case let .ma(period) = key else { return nil }
                return period
            }
            guard !periods.isEmpty else { return nil }
            return MARenderer(peroids: periods)
        }
        register(for: .ema) { indicator, configuration in
            let periods = configuration.indicatorKeys(for: indicator).compactMap { key -> Int? in
                guard case let .ema(period) = key else { return nil }
                return period
            }
            guard !periods.isEmpty else { return nil }
            return EMARenderer(peroids: periods)
        }
        register(for: .wma) { indicator, configuration in
            let periods = configuration.indicatorKeys(for: indicator).compactMap { key -> Int? in
                guard case let .wma(period) = key else { return nil }
                return period
            }
            guard !periods.isEmpty else { return nil }
            return WMARenderer(periods: periods)
        }
        register(for: .boll) { _, _ in
            BOLLRenderer()
        }
        register(for: .sar) { _, _ in
            SARRenderer()
        }
        register(for: .vol) { _, _ in
            VOLRenderer()
        }
        register(for: .rsi) { indicator, configuration in
            let periods = configuration.indicatorKeys(for: indicator).compactMap { key -> Int? in
                guard case let .rsi(period) = key else { return nil }
                return period
            }
            guard !periods.isEmpty else { return nil }
            return RSIRenderer(peroids: periods)
        }
        register(for: .macd) { _, _ in
            MACDRenderer()
        }
    }
}
