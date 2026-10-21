//
//  KLineMetricBounds.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2024/10/31.
//

import Foundation

/// The lower and upper values used to combine visible series and map prices to vertical coordinates.
public struct ValueBounds: Equatable, Sendable {
    /// The lower endpoint; positive infinity in the empty sentinel.
    public var min: Double
    /// The upper endpoint; negative infinity in the empty sentinel.
    public var max: Double
    /// Creates bounds from explicit endpoints without reordering or validating them.
    public init(min: Double, max: Double) {
        self.min = min
        self.max = max
    }
    
    /// Creates bounds from an ordered, closed value range.
    public init(range: ClosedRange<Double>) {
        self.min = range.lowerBound
        self.max = range.upperBound
    }
    
    /// The merge identity, represented by positive-infinity minimum and negative-infinity maximum.
    ///
    /// An empty range has a non-finite, negative distance and must not be used as a drawable price range.
    public static var empty: Self {
        ValueBounds(
            min: .infinity,
            max: -.infinity
        )
    }
}

extension ValueBounds {
    /// The upper endpoint minus the lower endpoint; zero for flat data and non-finite for the empty sentinel.
    public var distance: Double { max - min }
    
    /// Expands these bounds to include another range.
    ///
    /// - Parameter bounds: The range to include. Empty bounds act as the merge identity.
    public mutating func merge(other bounds: ValueBounds) {
        max = Swift.max(max, bounds.max)
        min = Swift.min(min, bounds.min)
    }
    
    /// Returns the combined range without modifying this value.
    public func merging(other bounds: ValueBounds) -> ValueBounds {
        let max = Swift.max(max, bounds.max)
        let min = Swift.min(min, bounds.min)
        return ValueBounds(min: min, max: max)
    }
}
