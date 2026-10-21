//
//  CandleDimensions.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/05/17.
//

import SwiftKLineCore
import UIKit

/// Mutable candle width and gap used by layout and pinch interaction, separate from immutable appearance defaults.
struct CandleDimensions: Equatable, Sendable {
    var width: CGFloat
    var gap: CGFloat

    init(width: CGFloat = 10, gap: CGFloat = 2) {
        self.width = width
        self.gap = gap
    }

    /// The horizontal stride from one candle body to the next.
    var itemWidth: CGFloat { width + gap }
}