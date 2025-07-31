//
//  ValueStorage.swift
//  KLine
//
//  Created by iya on 2024/11/1.
//

import Foundation

/// A thread-safe key-value storage system that can store values of any type.
///
/// This class provides type-safe storage with thread-safe operations using a serial dispatch queue.
/// All operations are synchronous by default to ensure immediate consistency.
///
/// Example:
/// ```
/// let storage = ValueStorage()
/// storage.set(value: 42, forKey: "answer")
/// let answer: Int? = storage.getValue(forKey: "answer", type: Int.self)
/// ```
final class ValueStorage: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.kline.valuestorage.queue",
                                     qos: .default,
                                     attributes: .concurrent)
    
    /// Type-erasure protocol for storing values of any type.
    private protocol AnyBox {
        /// Returns the ObjectIdentifier for the stored type
        var typeID: ObjectIdentifier { get }
        
        /// Returns the raw stored value without type safety
        func _unsafeGetRawValue() -> Any
    }

    /// Generic box that stores values of type T
    private final class Box<T>: AnyBox {
        /// The actual stored value
        let value: T
        
        /// Creates a box containing the given value
        /// - Parameter value: The value to store
        init(_ value: T) {
            self.value = value
        }

        /// The ObjectIdentifier for the stored type T
        var typeID: ObjectIdentifier {
            ObjectIdentifier(T.self)
        }

        /// Returns the stored value without type safety
        func _unsafeGetRawValue() -> Any {
            return value
        }
    }

    /// The underlying storage dictionary
    private var storage: [AnyHashable: AnyBox] = [:]
    
    /// Checks if a value exists for the given key (thread-safe)
    /// - Parameter key: The key to check
    /// - Returns: `true` if a value exists for the key, `false` otherwise
    func hasKey<Key: Hashable>(_ key: Key) -> Bool {
        queue.sync {
            storage.keys.contains(key)
        }
    }

    /// Stores a value for the given key (thread-safe)
    /// - Parameters:
    ///   - value: The value to store (can be any type)
    ///   - key: The key to associate with the value
    func set<Key: Hashable, Value>(value: Value, forKey key: Key) {
        queue.async(flags: .barrier) {
            self.storage[key] = Box(value)
        }
    }

    /// Retrieves a value for the given key with type safety (thread-safe)
    /// - Parameters:
    ///   - key: The key to look up
    ///   - type: The expected type of the value
    /// - Returns: The stored value if it exists and matches the expected type, otherwise nil
    func getValue<Key: Hashable, Value>(forKey key: Key, type: Value.Type) -> Value? {
        queue.sync {
            guard let box = storage[key], box.typeID == ObjectIdentifier(Value.self) else {
                return nil
            }
            return unsafeBitCast(box._unsafeGetRawValue(), to: Value.self)
        }
    }

    /// Removes the value for the given key (thread-safe)
    /// - Parameter key: The key whose value should be removed
    func remove<Key: Hashable>(forKey key: Key) {
        queue.async(flags: .barrier) {
            self.storage.removeValue(forKey: key)
        }
    }

    /// Merges the contents of another ValueStorage into this one (thread-safe)
    /// - Parameter other: The ValueStorage whose contents should be merged
    /// - Note: If there are duplicate keys, the values from `other` will overwrite existing values
    func merge(_ other: ValueStorage) {
        queue.async(flags: .barrier) {
            self.storage.merge(other.storage) { $1 }
        }
    }
}
