//
//  CandleStyle.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/05/17.
//

import SwiftKLineCore
import UIKit

/// The initial candle colors and dimensions; gesture-driven dimensions are tracked separately.
public struct CandleStyle: Equatable {
    /// The color for candles whose close is greater than or equal to their open.
    public let risingColor: UIColor
    /// The color for candles whose close is below their open.
    public let fallingColor: UIColor
    /// The initial candle body width in points; provide a positive value.
    public let width: CGFloat
    /// The initial spacing between bodies in points; provide a nonnegative value.
    public let gap: CGFloat

    /// Requires a finite positive width, finite nonnegative gap, and finite combined stride.
    public init(
        risingColor: UIColor = .systemTeal,
        fallingColor: UIColor = .systemPink,
        width: CGFloat = 10,
        gap: CGFloat = 2
    ) {
        precondition(width.isFinite && width > 0 && gap.isFinite && gap >= 0 && (width + gap).isFinite)
        self.risingColor = risingColor
        self.fallingColor = fallingColor
        self.width = width
        self.gap = gap
    }
}