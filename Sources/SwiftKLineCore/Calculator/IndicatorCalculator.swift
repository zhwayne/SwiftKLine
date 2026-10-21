//
//  IndicatorCalculator.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2024/11/01.
//

import Foundation

/// A Sendable calculation contract with one output slot per input candle.
///
/// A direct synchronous call runs in the caller’s context; IndicatorEngine schedules calculators in child tasks.
/// Warm-up or unavailable values are nil. Implementations should check cancellation during long loops.
public protocol IndicatorCalculator: Sendable {
    /// The Sendable value produced at each candle index.
    associatedtype Value: Sendable
    /// Stable series identity including every parameter that affects output semantics.
    var id: SeriesKey { get }
    /// Calculates the entire input in its existing order without sorting or mutating candles.
    ///
    /// - Parameter items: Chronological input candles.
    /// - Returns: One optional output per input index, including warm-up placeholders.
    func calculate(for items: [any ChartItem]) -> [Value?]

    /// Updates output from the earliest changed input index.
    ///
    /// The caller must keep the earlier input prefix and calculator configuration unchanged. The default implementation
    /// recalculates everything, so custom calculators remain correct without implementing incremental state.
    /// - Parameters:
    ///   - items: The complete, updated input.
    ///   - values: Previous aligned output, replaced or extended in place.
    ///   - index: Earliest index whose input or position changed.
    func update(for items: [any ChartItem], values: inout [Value?], from index: Int)
}

public extension IndicatorCalculator {
    /// Updates output from the earliest changed input index.
    ///
    /// The caller must keep the earlier input prefix and calculator configuration unchanged. The default implementation
    /// recalculates everything, so custom calculators remain correct without implementing incremental state.
    /// - Parameters:
    ///   - items: The complete, updated input.
    ///   - values: Previous aligned output, replaced or extended in place.
    ///   - index: Earliest index whose input or position changed.
    func update(for items: [any ChartItem], values: inout [Value?], from index: Int) {
        values = calculate(for: items)
    }

    /// Wraps this calculator so heterogeneous output types can share one Sendable calculator collection.
    func eraseToAnyIndicatorCalculator() -> AnyIndicatorCalculator { AnyIndicatorCalculator(self) }
}

/// Erases a calculator’s associated output type while preserving Sendable constraints.
///
/// Outputs are normalized to input length: extra entries are truncated and missing entries become nil.
/// Incremental reuse requires a compatible previous series and a valid unchanged prefix.
public struct AnyIndicatorCalculator: Sendable {
    /// The underlying calculator’s complete series identity.
    public let id: SeriesKey
    private let calculateValues: @Sendable ([any ChartItem], IndicatorSeriesStore?, Int) -> AnyIndicatorSeries

    /// Captures a Sendable calculator and its typed output conversion without retaining chart UI state.
    public init<C: IndicatorCalculator>(_ calculator: C) {
        id = calculator.id
        calculateValues = { items, previous, index in
            var values: [C.Value?]
            if index > 0, let cached = previous?.values(for: calculator.id, as: C.Value.self),
               index <= cached.count, index <= items.count {
                values = Array(cached)
                calculator.update(for: items, values: &values, from: index)
            } else {
                values = calculator.calculate(for: items)
            }
            // A malformed plugin must not cause out-of-range rendering or misaligned series.
            if values.count > items.count { values.removeLast(values.count - items.count) }
            if values.count < items.count { values.append(contentsOf: repeatElement(nil, count: items.count - values.count)) }
            return AnyIndicatorSeries(key: calculator.id, values: ContiguousArray(values))
        }
    }

    /// Runs a full synchronous calculation and returns a store containing this calculator’s aligned output.
    public func calculateStore(items: [any ChartItem]) -> IndicatorSeriesStore {
        calculateStore(items: items, previous: nil, from: 0)
    }

    /// Reuses a compatible prefix when possible, otherwise performs a full calculation.
    package func calculateStore(items: [any ChartItem], previous: IndicatorSeriesStore?, from index: Int) -> IndicatorSeriesStore {
        var store = IndicatorSeriesStore()
        store.setSeries(calculateValues(items, previous, index), for: id)
        return store
    }
}
