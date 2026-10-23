//
//  LayoutMetrics.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/05/17.
//

import SwiftKLineCore
import UIKit

/// Fixed chart-section heights in points, independent of candle zoom.
public struct LayoutMetrics: Equatable {
    /// The height of the main price chart.
    public let mainChartHeight: CGFloat
    /// The height reserved for the time axis below the main chart.
    public let timelineHeight: CGFloat
    /// The height of each selected lower indicator panel.
    public let indicatorHeight: CGFloat

    /// Creates chart-section metrics; callers should supply nonnegative heights.
    public init(
        mainChartHeight: CGFloat = 320,
        timelineHeight: CGFloat = 16,
        indicatorHeight: CGFloat = 64
    ) {
        self.mainChartHeight = mainChartHeight
        self.timelineHeight = timelineHeight
        self.indicatorHeight = indicatorHeight
    }
}
