//
//  TradeMarker.swift
//  SwiftKLineExample
//
//  Created by zhwayne on 2026/10/21.
//

#if canImport(UIKit)
import Foundation

/// An independently identified execution or signal, with a Unix-time-compatible event date.
struct TradeMarker: Identifiable, Sendable, Hashable {
    /// The execution or signal direction.
    enum Side: Sendable { case buy, sell }
    /// Stable event identity used to deduplicate overlapping pages.
    let id: String
    /// Event time; Date preserves subsecond precision when mapping to a candle.
    let timestamp: Date
    /// Execution or signal price in the chart price-axis units.
    let price: Double
    /// The direction used to select the marker glyph and color.
    let side: Side
    /// Creates an independent event without embedding a mutable candle-array index.
    init(id: String, timestamp: Date, price: Double, side: Side) {
        self.id = id; self.timestamp = timestamp; self.price = price; self.side = side
    }
}
#endif
