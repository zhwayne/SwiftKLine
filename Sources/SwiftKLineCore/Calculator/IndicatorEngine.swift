//
//  IndicatorEngine.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2024/11/01.
//

import Foundation

/// Coordinates independent indicator calculations using structured child tasks.
///
/// The engine owns no cache. Callers supply the exact previous output snapshot when requesting suffix updates.
/// Duplicate keys are merged in declaration order, with the last calculator winning, regardless of task completion order.
public enum IndicatorEngine {
    /// Calculates a coherent set of output series from one candle snapshot.
    ///
    /// - Parameters:
    ///   - items: Chronological input candles; indexes must match the supplied previous snapshot.
    ///   - calculators: Sendable calculators, ordered by duplicate-key precedence.
    ///   - previous: Optional prior output with the same calculator semantics.
    ///   - index: Earliest changed input index. Use zero for source replacement, prepended history, or changed parameters.
    /// - Returns: A Sendable output snapshot, or an empty store when the calling task is cancelled.
    ///
    /// Child tasks are awaited before this function returns. A synchronous plugin that ignores cancellation can delay completion.
    /// Suffix algorithms can reduce arithmetic work, but output arrays may still incur O(n) copy-on-write costs.
    public static func calculate(
        items: [any ChartItem],
        calculators: [AnyIndicatorCalculator],
        previous: IndicatorSeriesStore? = nil,
        invalidatedFrom index: Int = 0
    ) async -> IndicatorSeriesStore {
        guard !Task.isCancelled else { return IndicatorSeriesStore() }
        return await withTaskGroup(of: (Int, IndicatorSeriesStore).self) { group in
            for (offset, calculator) in calculators.enumerated() {
                group.addTask {
                    guard !Task.isCancelled else { return (offset, IndicatorSeriesStore()) }
                    return (offset, calculator.calculateStore(items: items, previous: previous, from: index))
                }
            }
            var outputs = [IndicatorSeriesStore?](repeating: nil, count: calculators.count)
            for await (offset, output) in group { outputs[offset] = output }
            guard !Task.isCancelled else { return IndicatorSeriesStore() }
            var result = IndicatorSeriesStore()
            // Duplicate keys resolve deterministically to the last declaration, not the fastest task.
            for output in outputs { if let output { result.merge(output) } }
            return result
        }
    }
}
