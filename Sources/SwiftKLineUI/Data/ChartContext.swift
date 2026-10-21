//
//  ChartContext.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2025/04/19.
//

import SwiftKLineCore
import UIKit

/// A main-actor rendering context containing one coherent candle and indicator snapshot.
///
/// The drawing coordinator updates group-specific geometry while iterating renderers. Read these values
/// during the current draw or legend call; do not retain the mutable context as a cache across passes.
@MainActor public final class ChartContext {
    let indicatorSeriesStore: IndicatorSeriesStore
    /// Changes whenever a coherent candle/indicator snapshot is published, including interior candle revisions.
    public let dataRevision: UInt64
    /// The full chronological candle snapshot corresponding to all indicator indexes.
    public let items: [any ChartItem]
    /// The chart’s captured creation-time visual configuration.
    public let configuration: ChartConfiguration
    let candleDimensions: CandleDimensions
    /// Absolute candle indexes included in this drawing pass.
    public let visibleRange: Range<Int>
    /// Coordinate conversion and current group value bounds, updated by the drawing coordinator.
    public let layout: ChartLayout
    /// The optional crosshair location in viewport-canvas coordinates.
    public let location: CGPoint?
    /// The selected absolute candle index, or the last visible index; it can be -1 for an empty range.
    public let currentIndex: Int
    /// The current section frame in viewport-canvas coordinates.
    public internal(set) var groupFrame: CGRect = .zero
    /// The current drawable section rectangle after legend space and padding are removed.
    public internal(set) var viewPort: CGRect = .zero
    /// The current section’s legend rectangle in viewport-canvas coordinates.
    public internal(set) var legendFrame: CGRect = .zero
    /// The attributed legend text prepared for the current group.
    public internal(set) var legendText: NSAttributedString?
    /// The current candle body width in points, including gesture-driven zoom.
    public var candleWidth: CGFloat { candleDimensions.width }
    /// The current gap between candle bodies in points.
    public var candleGap: CGFloat { candleDimensions.gap }

    init(
        indicatorSeriesStore: IndicatorSeriesStore,
        items: [any ChartItem],
        configuration: ChartConfiguration,
        candleDimensions: CandleDimensions,
        visibleRange: Range<Int>,
        layout: ChartLayout,
        location: CGPoint?,
        selectedIndex: Int?,
        dataRevision: UInt64 = 0
    ) {
        self.indicatorSeriesStore = indicatorSeriesStore
        self.items = items
        self.dataRevision = dataRevision
        self.configuration = configuration
        self.candleDimensions = candleDimensions
        self.visibleRange = visibleRange
        self.layout = layout
        self.location = location
        self.currentIndex = selectedIndex ?? visibleRange.upperBound - 1
    }
}

/// Context slicing and typed series access.
extension ChartContext {

    /// A slice retaining absolute candle indexes, or an empty slice when the visible range is invalid.
    public var visibleItems: ArraySlice<any ChartItem> {
        guard !items.isEmpty,
              visibleRange.lowerBound >= 0,
              visibleRange.upperBound <= items.count else {
            return []
        }
        return items[visibleRange]
    }

    /// Slices any aligned array after checking range validity; ArraySlice retains its original indexes.
    private func visibleValues<T>(from values: ContiguousArray<T>?) -> ArraySlice<T>? {
        guard let values else { return nil }
        guard !values.isEmpty,
              visibleRange.lowerBound >= 0,
              visibleRange.upperBound <= values.count else {
            return nil
        }
        return values[visibleRange]
    }

    /// Returns the visible portion of a typed indicator output without rebasing its indexes.
    ///
    /// - Parameters:
    ///   - key: Exact output identity, including calculation parameters.
    ///   - type: Exact output element type.
    /// - Returns: An absolute-indexed slice, or nil for a missing/type-mismatched series or invalid range.
    public func visibleValues<Value>(for key: SeriesKey, as type: Value.Type) -> ArraySlice<Value?>? {
        visibleValues(from: indicatorSeriesStore.values(for: key, as: type))
    }

    /// Returns the full output array for an exact series key and type, or nil when either does not match.
    public func values<Value>(
        for key: SeriesKey,
        as type: Value.Type
    ) -> ContiguousArray<Value?>? {
        indicatorSeriesStore.values(for: key, as: type)
    }
}

extension ChartContext {
    func scalarValues(for key: SeriesKey) -> ContiguousArray<Double?>? {
        indicatorSeriesStore.values(for: key, as: Double.self)
    }

    func visibleScalarValues(for key: SeriesKey) -> ArraySlice<Double?>? {
        visibleValues(from: scalarValues(for: key))
    }

    func bollValues(for key: SeriesKey = .boll(period: 20, k: 2.0)) -> ContiguousArray<BOLLIndicatorValue?>? {
        indicatorSeriesStore.values(for: key, as: BOLLIndicatorValue.self)
    }

    func visibleBollValues(for key: SeriesKey = .boll(period: 20, k: 2.0)) -> ArraySlice<BOLLIndicatorValue?>? {
        visibleValues(from: bollValues(for: key))
    }

    func macdValues(for key: SeriesKey = .macd(shortPeriod: 12, longPeriod: 26, signalPeriod: 9)) -> ContiguousArray<MACDIndicatorValue?>? {
        indicatorSeriesStore.values(for: key, as: MACDIndicatorValue.self)
    }

    func visibleMacdValues(for key: SeriesKey = .macd(shortPeriod: 12, longPeriod: 26, signalPeriod: 9)) -> ArraySlice<MACDIndicatorValue?>? {
        visibleValues(from: macdValues(for: key))
    }
}
