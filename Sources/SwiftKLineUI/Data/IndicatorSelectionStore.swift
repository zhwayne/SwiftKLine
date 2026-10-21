//
//  IndicatorSelectionStore.swift
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
public struct IndicatorSelectionState: Codable, Equatable, Sendable {
    /// Selected main or overlay plugin IDs in display order.
    public var mainIndicatorIDs: [IndicatorID]
    /// Selected lower-panel plugin IDs in display order.
    public var subIndicatorIDs: [IndicatorID]

    /// Creates a selection that can contain both built-in and custom indicator IDs.
    public init(mainIndicatorIDs: [IndicatorID] = [], subIndicatorIDs: [IndicatorID] = []) {
        self.mainIndicatorIDs = mainIndicatorIDs
        self.subIndicatorIDs = subIndicatorIDs
    }

    /// Compatibility initializer; prefer explicit mainIndicatorIDs and subIndicatorIDs labels.
    @available(*, deprecated, renamed: "init(mainIndicatorIDs:subIndicatorIDs:)")
    public init(main: [IndicatorID] = [], sub: [IndicatorID] = []) {
        self.init(mainIndicatorIDs: main, subIndicatorIDs: sub)
    }

    /// Creates a selection from built-in indicators by mapping each to its open ID.
    public init(mainIndicators: [BuiltInIndicator] = [], subIndicators: [BuiltInIndicator] = []) {
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

    var indicatorIDs: [IndicatorID] {
        mainIndicatorIDs + subIndicatorIDs
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
        self.mainIndicatorIDs = try container.decode([IndicatorID].self, forKey: .main)
        self.subIndicatorIDs = try container.decode([IndicatorID].self, forKey: .sub)
    }

    private enum CodingKeys: String, CodingKey {
        case main, sub
    }
}

/// Synchronous persistence used by the chart’s main-actor selection pipeline.
///
/// Implementations may back selection with UserDefaults or application storage. The chart does not invoke
/// these methods from calculator tasks.
public protocol IndicatorSelectionStore {
    /// Returns a previously saved selection, or nil when no usable selection exists.
    func load() -> IndicatorSelectionState?
    /// Persists the supplied normalized selection.
    func save(state: IndicatorSelectionState)
    /// Removes the persisted selection so the chart can restore its configured defaults.
    func reset()
}

/// Stores selection as a property list in a configurable UserDefaults key; intended for serialized chart access.
public final class UserDefaultsIndicatorSelectionStore: IndicatorSelectionStore {

    /// The shared default key; use a different key to isolate selections between markets or charts.
    public static let defaultKey = "com.swiftkline.indicator.selection"

    private let userDefaults: UserDefaults
    private let key: String
    private let encoder = PropertyListEncoder()
    private let decoder = PropertyListDecoder()

    /// Creates a selection store using the supplied defaults domain and storage key.
    public init(
        userDefaults: UserDefaults = .standard,
        key: String = UserDefaultsIndicatorSelectionStore.defaultKey
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    /// Decodes the saved property list, returning nil for absent or unreadable data.
    public func load() -> IndicatorSelectionState? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? decoder.decode(IndicatorSelectionState.self, from: data)
    }

    /// Encodes a normalized selection as a property list; encoding failure leaves storage unchanged.
    public func save(state: IndicatorSelectionState) {
        guard let data = try? encoder.encode(state) else { return }
        userDefaults.set(data, forKey: key)
    }

    /// Removes only this store’s configured selection key.
    public func reset() {
        userDefaults.removeObject(forKey: key)
    }
}
