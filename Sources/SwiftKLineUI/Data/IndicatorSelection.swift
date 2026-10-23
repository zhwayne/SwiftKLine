//
//  IndicatorSelection.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2025/11/26.
//

import SwiftKLineCore
import Foundation

/// An ordered, persistable indicator selection using open IDs.
///
/// The value itself does not validate placements, availability, or duplicates; ChartView normalizes submitted selections.
/// Compatibility encoding retains the historical "main" and "sub" storage keys.
public struct IndicatorSelection: Codable, Equatable, Sendable {
    /// Selected main or overlay plugin IDs in display order.
    public var mainIndicatorIDs: [IndicatorID]
    /// Selected lower-panel plugin IDs in display order.
    public var subIndicatorIDs: [IndicatorID]

    /// Creates a selection from open IDs; the chart filters unsupported values.
    public init(mainIndicatorIDs: [IndicatorID] = [], subIndicatorIDs: [IndicatorID] = []) {
        self.mainIndicatorIDs = mainIndicatorIDs
        self.subIndicatorIDs = subIndicatorIDs
    }

    /// Compatibility initializer; prefer explicit mainIndicatorIDs and subIndicatorIDs labels.
    @available(*, deprecated, renamed: "init(mainIndicatorIDs:subIndicatorIDs:)")
    public init(main: [IndicatorID], sub: [IndicatorID] = []) {
        self.init(mainIndicatorIDs: main, subIndicatorIDs: sub)
    }

    /// Creates a selection from built-in indicators by mapping each to its open ID.
    public init(mainIndicators: [BuiltInIndicator], subIndicators: [BuiltInIndicator] = []) {
        self.mainIndicatorIDs = mainIndicators.map(\.id)
        self.subIndicatorIDs = subIndicators.map(\.id)
    }

    /// Compatibility alias for mainIndicatorIDs.
    @available(*, deprecated, renamed: "mainIndicatorIDs")
    public var main: [IndicatorID] {
        get { mainIndicatorIDs }
        set { mainIndicatorIDs = newValue }
    }

    /// Compatibility alias for subIndicatorIDs.
    @available(*, deprecated, renamed: "subIndicatorIDs")
    public var sub: [IndicatorID] {
        get { subIndicatorIDs }
        set { subIndicatorIDs = newValue }
    }

    /// The built-in subset of the main selection; custom IDs are omitted.
    public var mainIndicators: [BuiltInIndicator] {
        mainIndicatorIDs.compactMap { BuiltInIndicator(id: $0) }
    }

    /// The built-in subset of the lower selection; custom IDs are omitted.
    public var subIndicators: [BuiltInIndicator] {
        subIndicatorIDs.compactMap { BuiltInIndicator(id: $0) }
    }

    var indicatorIDs: [IndicatorID] { mainIndicatorIDs + subIndicatorIDs }

    /// Encodes open IDs under the historical main/sub keys to preserve stored selection compatibility.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mainIndicatorIDs, forKey: .main)
        try container.encode(subIndicatorIDs, forKey: .sub)
    }

    /// Decodes the historical main/sub representation; invalid or missing fields propagate a decoding error.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mainIndicatorIDs = try container.decode([IndicatorID].self, forKey: .main)
        subIndicatorIDs = try container.decode([IndicatorID].self, forKey: .sub)
    }

    private enum CodingKeys: String, CodingKey { case main, sub }
}
