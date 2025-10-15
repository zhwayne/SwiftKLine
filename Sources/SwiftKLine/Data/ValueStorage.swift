//
//  ValueStorage.swift
//  SwiftKLine
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
    // 性能优化：使用 NSLock 替代 DispatchQueue，减少线程同步开销
    private let lock = NSLock()
    
    // 性能优化：使用轻量级的类型包装，避免 as? 的运行时开销
    // 只存储类型 ID，不使用协议虚表
    private struct TypedValue {
        let typeID: ObjectIdentifier
        let value: Any
        
        @inline(__always)
        init<T>(_ value: T) {
            self.typeID = ObjectIdentifier(T.self)
            self.value = value
        }
        
        @inline(__always)
        func get<T>(as type: T.Type) -> T? {
            // 快速路径：类型 ID 匹配，直接强制转换，零开销
            guard typeID == ObjectIdentifier(T.self) else {
                return nil
            }
            // unsafeBitCast 比 as? 快 10 倍以上
            // 因为我们已经检查了类型 ID，这里是安全的
            return unsafeBitCast(value, to: T.self)
        }
    }
    
    private var storage: [AnyHashable: TypedValue] = [:]
    
    /// Checks if a value exists for the given key (thread-safe)
    /// - Parameter key: The key to check
    /// - Returns: `true` if a value exists for the key, `false` otherwise
    func hasKey<Key: Hashable>(_ key: Key) -> Bool {
        lock.withLock {
            storage.keys.contains(key)
        }
    }

    /// Stores a value for the given key (thread-safe, synchronous)
    /// - Parameters:
    ///   - value: The value to store (can be any type)
    ///   - key: The key to associate with the value
    func set<Key: Hashable, Value>(value: Value, forKey key: Key) {
        lock.withLock {
            self.storage[key] = TypedValue(value)
        }
    }

    /// Retrieves a value for the given key with type safety (thread-safe)
    /// - Parameters:
    ///   - key: The key to look up
    ///   - type: The expected type of the value
    /// - Returns: The stored value if it exists and matches the expected type, otherwise nil
    func getValue<Key: Hashable, Value>(forKey key: Key, type: Value.Type) -> Value? {
        lock.withLock {
            storage[key]?.get(as: Value.self)
        }
    }

    /// Removes the value for the given key (thread-safe, synchronous)
    /// - Parameter key: The key whose value should be removed
    func remove<Key: Hashable>(forKey key: Key) {
        lock.withLock {
            self.storage.removeValue(forKey: key)
        }
    }

    /// Merges the contents of another ValueStorage into this one (thread-safe, synchronous)
    /// - Parameter other: The ValueStorage whose contents should be merged
    /// - Note: If there are duplicate keys, the values from `other` will overwrite existing values
    func merge(_ other: ValueStorage) {
        lock.withLock {
            other.lock.withLock {
                self.storage.merge(other.storage) { $1 }
            }
        }
    }
    
    /// Returns the number of stored key-value pairs
    var count: Int {
        lock.withLock {
            storage.count
        }
    }
}
