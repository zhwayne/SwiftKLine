//
//  IndicatorSelection.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2025/11/26.
//

import SwiftKLineCore
import Foundation

/// Ordered, persistable built-in indicator choices represented by stable IDs.
///
/// Charts derive a supported subset without changing the requested value. Custom plugins are declared
/// separately in ChartConfiguration.plugins; this value does not enable or disable them.
/// Compatibility encoding retains the historical "main" and "sub" storage keys.
public struct IndicatorSelection: Codable, Equatable, Sendable {
    /// Requested built-in main indicator IDs in display order.
    public var mainIndicatorIDs: [IndicatorID]
    /// Requested built-in lower-panel indicator IDs in display order.
    public var subIndicatorIDs: [IndicatorID]

    /// Creates a selection from stable IDs; unsupported IDs are omitted from rendering.
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

    /// Returns available built-ins in their requested order, removing duplicates and misplaced IDs.
    /// The original selection is preserved, so temporarily unavailable indicators can return later.
    public func resolved(availableIndicators: [BuiltInIndicator]) -> IndicatorSelection {
        let available = Set(availableIndicators)
        func filter(_ ids: [IndicatorID], main: Bool) -> [IndicatorID] {
            var seen = Set<IndicatorID>()
            return ids.filter { id in
                guard let indicator = BuiltInIndicator(id: id), available.contains(indicator),
                      indicator.isMain == main else { return false }
                return seen.insert(id).inserted
            }
        }
        return IndicatorSelection(mainIndicatorIDs: filter(mainIndicatorIDs, main: true),
                                  subIndicatorIDs: filter(subIndicatorIDs, main: false))
    }

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
