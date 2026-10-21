//
//  Sequence+IndicatorCalculation.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2024/11/01.
//

import Foundation

public extension Sequence where Element == AnyIndicatorCalculator {
    /// Calculates a heterogeneous sequence in declaration order by delegating to IndicatorEngine without a previous snapshot.
    func calculate(items: [any ChartItem]) async -> IndicatorSeriesStore {
        await IndicatorEngine.calculate(items: items, calculators: Array(self))
    }
}
