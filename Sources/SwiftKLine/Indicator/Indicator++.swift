//
//  SwiftKLine.swift
//  SwiftKLine
//
//  Created by W Zh on 2025/7/26.
//

import Foundation

extension Indicator {
    
    /// 兼容层：外部仍通过 `Indicator` 拿 calculators，
    /// 内部实现统一转发到 `IndicatorCatalog`。
    @MainActor func makeCalculators(configuration: KLineConfiguration) -> [any IndicatorCalculator] {
        IndicatorCatalog
            .spec(for: self)?
            .makeCalculators(configuration: configuration) ?? []
    }
}
