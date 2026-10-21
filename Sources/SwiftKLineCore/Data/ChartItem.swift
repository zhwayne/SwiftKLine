//
//  ChartItem.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2024/10/31.
//

import Foundation

/// The immutable candle interface consumed by calculations and chart rendering.
///
/// Supply finite prices, volume, and traded amount, with high greater than or equal to low.
/// Values cross task boundaries, so conforming reference types must also enforce Sendable safety.
/// Merging uses timestamp as candle identity regardless of any custom Identifiable conformance.
public protocol ChartItem: Equatable, Identifiable, Sendable {
    /// The opening price.
    var open: Double { get }
    /// The latest or final closing price.
    var close: Double { get }
    /// The highest price in the candle.
    var high: Double { get }
    /// The lowest price in the candle.
    var low: Double  { get }
    /// The traded quantity, expressed in the source’s base units.
    var volume: Double  { get }
    /// The traded amount, expressed in the source’s quote units.
    var value: Double   { get }
    /// The candle-open Unix timestamp in seconds; it must remain stable across revisions.
    var timestamp: Int  { get }
}

extension ChartItem {
    
    /// Uses the candle-open timestamp as the default stable identity.
    public var id: Int { timestamp }
}

extension ChartItem {
    
    /// The price range of this candle, or the combined range of all candles in the collection.
    package var dataBounds: ValueBounds {
        return ValueBounds(min: low, max: high)
    }
}

extension Collection where Element == any ChartItem {
    
    /// The first minimum-low candle and its offset relative to this collection, not its absolute array index.
    package var lowerBoundItem: (Int, Element)? {
        guard let first = self.first else { return nil }
        var (idx, element) = (0, first)
        for (offset, item) in self.dropFirst().enumerated() {
            if item.low < element.low {
                (idx, element) = (offset + 1, item)
            }
        }
        return (idx, element)
    }
    
    /// The first maximum-high candle and its offset relative to this collection, not its absolute array index.
    package var upperBoundItem: (Int, Element)? {
        guard let first = self.first else { return nil }
        var (idx, element) = (0, first)
        for (offset, item) in self.dropFirst().enumerated() {
            if item.high > element.high {
                (idx, element) = (offset + 1, item)
            }
        }
        return (idx, element)
    }
    
    /// The price range of this candle, or the combined range of all candles in the collection.
    package var dataBounds: ValueBounds {
        return reduce(into: .empty) { partialResult, item in
            partialResult.merge(other: item.dataBounds)
        }
    }
}

