//
//  ChartStateStore.swift
//  SwiftKLineExample
//
//  Created by zhwayne on 2026/10/23.
//

#if canImport(UIKit)
import Foundation

/// A type-safe key for a Codable, Sendable value within a state store.
struct ChartStateKey<Value: Codable & Sendable>: Hashable, Sendable {
    /// The relative key used for reading, writing, and removal.
    let rawValue: String

    /// Creates a nonempty key relative to the store's namespace.
    init(_ rawValue: String) {
        precondition(!rawValue.isEmpty)
        self.rawValue = rawValue
    }
}

/// Synchronous storage for application-owned chart preferences and other state.
/// Backends receive relative keys and can apply their own namespace.
@MainActor
protocol ChartStateStore: AnyObject {
    /// Returns raw data for a key, or nil when no value exists.
    func data(forKey key: String) -> Data?
    /// Replaces raw data for a key.
    func set(_ data: Data, forKey key: String)
    /// Removes a stored key.
    func removeValue(forKey key: String)
}

extension ChartStateStore {
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

/// Application preference storage backed by UserDefaults.
@MainActor
final class UserDefaultsChartStateStore: ChartStateStore {
    private let defaults: UserDefaults
    private let namespace: String

    /// Creates a store in the supplied defaults domain and namespace.
    /// The default namespace preserves existing indicator-selection data.
    /// Use an empty namespace to store relative keys without a prefix.
    init(defaults: UserDefaults = .standard, namespace: String = "com.swiftkline") {
        self.defaults = defaults
        self.namespace = namespace
    }

    func data(forKey key: String) -> Data? { defaults.data(forKey: storageKey(for: key)) }
    func set(_ data: Data, forKey key: String) { defaults.set(data, forKey: storageKey(for: key)) }
    func removeValue(forKey key: String) { defaults.removeObject(forKey: storageKey(for: key)) }

    private func storageKey(for key: String) -> String {
        namespace.isEmpty ? key : "\(namespace).\(key)"
    }
}

/// Application-owned in-memory storage for previews, tests, and ephemeral sessions.
@MainActor
final class MemoryChartStateStore: ChartStateStore {
    private var values: [String: Data]

    /// Creates a store with optional raw seed data.
    init(values: [String: Data] = [:]) {
        self.values = values
    }

    func data(forKey key: String) -> Data? { values[key] }
    func set(_ data: Data, forKey key: String) { values[key] = data }
    func removeValue(forKey key: String) { values.removeValue(forKey: key) }
}

extension ChartStateKey where Value == ChartPreferences {
    /// Storage key for an application-owned chart preference snapshot.
    static var chartPreferences: ChartStateKey<ChartPreferences> {
        ChartStateKey("chart.preferences")
    }
}
#endif
