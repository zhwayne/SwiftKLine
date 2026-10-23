//
//  ChartStateStore.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/10/23.
//

import Foundation

/// A type-safe key for a Codable, Sendable value within a state store.
public struct ChartStateKey<Value: Codable & Sendable>: Hashable, Sendable {
    /// The relative key used for reading, writing, and removal.
    public let rawValue: String

    /// Creates a nonempty key relative to the store's namespace.
    public init(_ rawValue: String) {
        precondition(!rawValue.isEmpty)
        self.rawValue = rawValue
    }
}

/// Synchronous data storage used from the chart's main-actor state pipeline.
/// Backends receive relative keys and can apply their own namespace.
@MainActor
public protocol ChartStateStore: AnyObject {
    /// Returns raw data for a key, or nil when no value exists.
    func data(forKey key: String) -> Data?
    /// Replaces raw data for a key.
    func set(_ data: Data, forKey key: String)
    /// Removes a stored key.
    func removeValue(forKey key: String)
}

public extension ChartStateStore {
    /// Decodes a typed value, accepting current JSON and legacy property-list data.
    func value<Value: Codable & Sendable>(for key: ChartStateKey<Value>) -> Value? {
        guard let data = data(forKey: key.rawValue) else { return nil }
        if let value = try? JSONDecoder().decode(Value.self, from: data) { return value }
        return try? PropertyListDecoder().decode(Value.self, from: data)
    }

    /// Encodes and stores a typed value as JSON.
    func set<Value: Codable & Sendable>(_ value: Value, for key: ChartStateKey<Value>) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        set(data, forKey: key.rawValue)
    }

    /// Removes a typed key without requiring a placeholder value.
    func removeValue<Value: Codable & Sendable>(for key: ChartStateKey<Value>) {
        removeValue(forKey: key.rawValue)
    }
}

/// A UserDefaults-backed state store supplied by SwiftKLine.
@MainActor
public final class UserDefaultsChartStateStore: ChartStateStore {
    private let defaults: UserDefaults
    private let namespace: String

    /// Creates a store in the supplied defaults domain and namespace.
    /// The default namespace preserves existing indicator-selection data.
    /// Use an empty namespace to store relative keys without a prefix.
    public init(defaults: UserDefaults = .standard, namespace: String = "com.swiftkline") {
        self.defaults = defaults
        self.namespace = namespace
    }

    public func data(forKey key: String) -> Data? { defaults.data(forKey: storageKey(for: key)) }
    public func set(_ data: Data, forKey key: String) { defaults.set(data, forKey: storageKey(for: key)) }
    public func removeValue(forKey key: String) { defaults.removeObject(forKey: storageKey(for: key)) }

    private func storageKey(for key: String) -> String {
        namespace.isEmpty ? key : "\(namespace).\(key)"
    }
}

/// An in-memory state store for previews, tests, and ephemeral sessions.
@MainActor
public final class MemoryChartStateStore: ChartStateStore {
    private var values: [String: Data]

    /// Creates a store with optional raw seed data.
    public init(values: [String: Data] = [:]) {
        self.values = values
    }

    public func data(forKey key: String) -> Data? { values[key] }
    public func set(_ data: Data, forKey key: String) { values[key] = data }
    public func removeValue(forKey key: String) { values.removeValue(forKey: key) }
}

extension ChartStateKey where Value == ChartSelection {
    /// Internal key for the complete chart selection.
    static var chartSelection: ChartStateKey<ChartSelection> {
        ChartStateKey("chart.selection")
    }
}
