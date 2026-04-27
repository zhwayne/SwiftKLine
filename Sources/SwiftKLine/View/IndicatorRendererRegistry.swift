//
//  IndicatorRendererRegistry.swift
//  SwiftKLine
//
//  Created by zhwayne on 2025/11/13.
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
    
    /// 默认渲染器注册：统一从 `IndicatorCatalog` 读取，避免各指标散落注册逻辑。
    private func registerDefaultRenderers() {
        for spec in IndicatorCatalog.allSpecs {
            register(for: spec.indicator) { _, configuration in
                spec.makeRenderer(configuration: configuration)
            }
        }
    }
}
