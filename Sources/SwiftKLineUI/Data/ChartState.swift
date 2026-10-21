//
//  ChartState.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/05/17.
//

import SwiftKLineCore
import CoreGraphics
import Foundation

/// Coordinator-owned data and selection state.
///
/// Raw items can advance ahead of indicatorSeriesStore while a calculation is running.
/// ChartView publishes its own matched candle/output snapshot only after calculation completes.
struct ChartState {
    var items: [any ChartItem]
    var indicatorSeriesStore: IndicatorSeriesStore
    var contentStyle: ChartType
    var selectedIndex: Int?
    var selectedLocation: CGPoint?
    var lastError: Error?
    var indicatorSelection: IndicatorSelectionState

    var mainIndicators: [BuiltInIndicator] { indicatorSelection.mainIndicators }
    var subIndicators: [BuiltInIndicator] { indicatorSelection.subIndicators }

    init(
        items: [any ChartItem] = [],
        indicatorSeriesStore: IndicatorSeriesStore = IndicatorSeriesStore(),
        contentStyle: ChartType = .candlestick,
        selectedIndex: Int? = nil,
        selectedLocation: CGPoint? = nil,
        lastError: Error? = nil,
        indicatorSelection: IndicatorSelectionState = IndicatorSelectionState(mainIndicatorIDs: [], subIndicatorIDs: [])
    ) {
        self.items = items
        self.indicatorSeriesStore = indicatorSeriesStore
        self.contentStyle = contentStyle
        self.selectedIndex = selectedIndex
        self.selectedLocation = selectedLocation
        self.lastError = lastError
        self.indicatorSelection = indicatorSelection
    }
}
