//
//  ChartContentStyle.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/04/27.
//

import SwiftKLineCore
/// The main-chart presentation, independent of indicator selection and provider configuration.
public enum ChartType: Equatable, Sendable {
    /// Draws open, high, low, and close values as candles.
    case candlestick
    /// Draws close prices as a connected line with optional fill.
    case timeSeries
}
