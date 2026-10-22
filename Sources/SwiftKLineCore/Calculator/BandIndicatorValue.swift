//
//  BandIndicatorValue.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2026/10/22.
//

import Foundation

/// The upper, middle, and lower prices of one channel indicator at a single candle.
///
/// A channel is stored as one typed output instead of three unrelated scalar series. That keeps the
/// calculator, series identity, style lookup, and renderer registration aligned: one key describes one
/// complete channel, and renderers can merge all three prices into the visible value bounds.
public struct BandIndicatorValue: Equatable, Sendable {
    /// The upper channel price.
    public let upper: Double
    /// The middle or basis price.
    public let middle: Double
    /// The lower channel price.
    public let lower: Double

    /// The lowest of the three prices, used when combining visible drawing bounds.
    public var min: Double { Swift.min(lower, middle, upper) }
    /// The highest of the three prices, used when combining visible drawing bounds.
    public var max: Double { Swift.max(lower, middle, upper) }

    /// Creates one channel value without validating or reordering the supplied prices.
    ///
    /// - Parameters:
    ///   - upper: The upper channel price.
    ///   - middle: The middle or basis price.
    ///   - lower: The lower channel price.
    public init(upper: Double, middle: Double, lower: Double) {
        self.upper = upper
        self.middle = middle
        self.lower = lower
    }
}
