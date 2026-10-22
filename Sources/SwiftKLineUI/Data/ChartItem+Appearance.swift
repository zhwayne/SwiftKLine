//
//  ChartItem+Appearance.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2024/10/31.
//

import SwiftKLineCore
import UIKit

/// Internal price-direction classification used to choose configured candle colors.
enum Trend: Sendable {
    case rising, falling
    @MainActor func color(using configuration: ChartAppearance) -> UIColor {
        self == .rising ? configuration.candleStyle.risingColor : configuration.candleStyle.fallingColor
    }
}

extension ChartItem {
    
    /// Treats equal open and close prices as rising for consistent color selection.
    var trend: Trend {
        if open > close { return .falling }
        return .rising
    }
}
