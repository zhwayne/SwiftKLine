//
//  IndicatorCalculationEngine.swift
//  SwiftKLine
//

import Foundation

@MainActor
struct IndicatorCalculationEngine {
    func calculate(
        items: [any KLineItem],
        mainIndicators: [Indicator],
        subIndicators: [Indicator],
        configuration: KLineConfiguration
    ) async -> IndicatorSeriesStore {
        let calculators = (mainIndicators + subIndicators)
            .flatMap { indicator in indicator.makeCalculators(configuration: configuration) }
        return await calculate(items: items, calculators: calculators)
    }

    func calculate(
        items: [any KLineItem],
        calculators: [any IndicatorCalculator]
    ) async -> IndicatorSeriesStore {
        guard !calculators.isEmpty else { return IndicatorSeriesStore() }
        return await calculators.calculate(items: items)
    }
}
