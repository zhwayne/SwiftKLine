//
//  IndicatorRendererRegistry.swift
//  SwiftKLine
//
//  Created by W Zh on 2025/11/13.
//

import Foundation

@MainActor
final class IndicatorRendererRegistry {
    typealias Provider = (Indicator) -> (any Renderer)?
    
    static let shared = IndicatorRendererRegistry()
    private var providers: [Indicator: [Provider]] = [:]
    
    private init() {
        registerDefaultRenderers()
    }
    
    func register(for indicator: Indicator, provider: @escaping Provider) {
        providers[indicator, default: []].append(provider)
    }
    
    func renderers(for indicator: Indicator) -> [AnyRenderer] {
        guard let providers = providers[indicator] else { return [] }
        return providers.compactMap { provider in
            guard let renderer = provider(indicator) else { return nil }
            return renderer.eraseToAnyRenderer()
        }
    }
}


extension IndicatorRendererRegistry {
    
    private func registerDefaultRenderers() {
        register(for: .ma) { indicator in
            MARenderer(peroids: indicator.keys.compactMap({ key in
                guard case let .ma(period) = key else { return nil }
                return period
            }))
        }
        register(for: .ema) { indicator in
            EMARenderer(peroids: indicator.keys.compactMap({ key in
                guard case let .ema(period) = key else { return nil }
                return period
            }))
        }
        register(for: .boll) { _ in
            BOLLRenderer()
        }
        register(for: .sar) { _ in
            SARRenderer()
        }
        register(for: .vol) { _ in
            VOLRenderer()
        }
        register(for: .rsi) { indicator in
            RSIRenderer(peroids: indicator.keys.compactMap({ key in
                guard case let .rsi(period) = key else { return nil }
                return period
            }))
        }
        register(for: .macd) { _ in
            MACDRenderer()
        }
    }
}
