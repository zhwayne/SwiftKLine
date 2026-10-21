//
//  Candle.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2026/10/21.
//

import Foundation

/// An immutable OHLCV candle with timestamp-based identity.
///
/// All numeric inputs must be finite, and high must be greater than or equal to low.
/// The initializer stores values as supplied; it does not validate exchange-specific price or volume rules.
/// Use the same candle-open timestamp for every revision of one candle.
public struct Candle: ChartItem, Codable, Hashable {
    /// The candle-open Unix timestamp, in seconds rather than milliseconds.
    public let timestamp: Int
    /// The first traded price in the candle.
    public let open: Double
    /// The highest traded price in the candle.
    public let high: Double
    /// The lowest traded price in the candle.
    public let low: Double
    /// The latest traded price, or the final price after the candle closes.
    public let close: Double
    /// Traded quantity in the data source’s base units; defaults to zero when unavailable.
    public let volume: Double
    /// Traded amount in the data source’s quote units; defaults to zero when unavailable.
    public let value: Double

    /// Creates a complete candle snapshot without normalizing its values.
    ///
    /// - Parameters:
    ///   - timestamp: Candle-open Unix time in seconds. Keep this stable across live revisions.
    ///   - open: Opening price.
    ///   - high: Highest price.
    ///   - low: Lowest price.
    ///   - close: Latest or closing price.
    ///   - volume: Traded quantity in the source’s base units.
    ///   - value: Traded amount in the source’s quote units.
    public init(timestamp: Int, open: Double, high: Double, low: Double, close: Double,
                volume: Double = 0, value: Double = 0) {
        self.timestamp = timestamp
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.value = value
    }
}
