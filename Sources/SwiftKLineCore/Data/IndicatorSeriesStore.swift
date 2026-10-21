//
//  IndicatorSeriesStore.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2026/02/07.
//

import Foundation

/// A typed series erased behind a compiler-checked Sendable existential.
///
/// The stored array is a value snapshot. No unchecked sendability assumption is required for its elements.
package struct AnyIndicatorSeries: Sendable {
    let key: SeriesKey
    private let storage: any Sendable

    init<Value: Sendable>(key: SeriesKey, values: ContiguousArray<Value?>) {
        self.key = key
        storage = values
    }

    func values<Value>(as type: Value.Type) -> ContiguousArray<Value?>? {
        storage as? ContiguousArray<Value?>
    }
}

/// A Sendable value snapshot of heterogeneous indicator outputs indexed by SeriesKey.
///
/// Reads require the exact output type. Copying this store can share array storage until a later mutation.
public struct IndicatorSeriesStore: Sendable {
    private var series: [SeriesKey: AnyIndicatorSeries] = [:]

    /// Creates an empty output snapshot.
    public init() {}

    /// Stores an already-erased output, replacing any entry at the supplied key.
    package mutating func setSeries(_ value: AnyIndicatorSeries, for key: SeriesKey) {
        series[key] = value
    }

    /// Stores a typed series, replacing the previous value for the same key.
    ///
    /// - Parameters:
    ///   - values: Values aligned to the corresponding input candles; nil represents unavailable or warm-up output.
    ///   - key: Stable identity including every parameter that changes the series meaning.
    public mutating func setValues<Value: Sendable>(_ values: ContiguousArray<Value?>, for key: SeriesKey) {
        series[key] = AnyIndicatorSeries(key: key, values: values)
    }

    /// Returns an output series only when both its key and element type match.
    ///
    /// - Parameters:
    ///   - key: The requested series identity.
    ///   - type: The exact non-optional output type, such as Double.self.
    /// - Returns: A snapshot preserving input indexes, or nil if the key is absent or the stored type differs.
    public func values<Value>(for key: SeriesKey, as type: Value.Type) -> ContiguousArray<Value?>? {
        series[key]?.values(as: type)
    }

    /// Merges another output snapshot, letting its entries replace duplicate keys.
    public mutating func merge(_ other: IndicatorSeriesStore) {
        series.merge(other.series) { _, new in new }
    }
}
