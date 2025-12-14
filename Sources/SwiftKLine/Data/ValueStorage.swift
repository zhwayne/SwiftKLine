//
//  ValueStorage.swift
//  SwiftKLine
//
//  Created by iya on 2024/11/1.
//

import Foundation
import os.lock

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
    // 使用 os_unfair_lock 获取更低的加锁开销
    private var lock = os_unfair_lock_s()
    
    // 性能优化：使用轻量级的类型包装，避免 as? 的运行时开销
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
            return unsafeBitCast(value, to: T.self)
        }
    }
    
    private var storage: [AnyHashable: TypedValue] = [:]
    
    /// Checks if a value exists for the given key (thread-safe)
    /// - Parameter key: The key to check
    /// - Returns: `true` if a value exists for the key, `false` otherwise
    @inline(__always)
    func hasKey<Key: Hashable>(_ key: Key) -> Bool {
        withLock {
            storage[key] != nil
        }
    }

    /// Stores a value for the given key (thread-safe, synchronous)
    /// - Parameters:
    ///   - value: The value to store (can be any type)
    ///   - key: The key to associate with the value
    @inline(__always)
    func set<Key: Hashable, Value>(value: Value, forKey key: Key) {
        withLock {
            self.storage[key] = TypedValue(value)
        }
    }

    /// Retrieves a value for the given key with type safety (thread-safe)
    /// - Parameters:
    ///   - key: The key to look up
    ///   - type: The expected type of the value
    /// - Returns: The stored value if it exists and matches the expected type, otherwise nil
    @inline(__always)
    func getValue<Key: Hashable, Value>(forKey key: Key, type: Value.Type) -> Value? {
        withLock {
            storage[key]?.get(as: Value.self)
        }
    }

    /// Removes the value for the given key (thread-safe, synchronous)
    /// - Parameter key: The key whose value should be removed
    @inline(__always)
    func remove<Key: Hashable>(forKey key: Key) {
        withLock {
            self.storage.removeValue(forKey: key)
        }
    }

    /// Returns the number of stored key-value pairs
    var count: Int {
        withLock {
            storage.count
        }
    }
    
    @inline(__always)
    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return try body()
    }
}
