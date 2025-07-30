//
//  ValueStorage.swift
//  KLine
//
//  Created by iya on 2024/11/1.
//

import Foundation

/// ValueStorage 本身非线程安全
final class ValueStorage: @unchecked Sendable {
    
    // 类型擦除协议
    private protocol AnyBox {
        var typeID: ObjectIdentifier { get }
        func _unsafeGetRawValue() -> Any
    }

    // 泛型封装盒子，支持任意类型（值或数组）
    private final class Box<T>: AnyBox {
        let value: T
        init(_ value: T) {
            self.value = value
        }

        var typeID: ObjectIdentifier {
            ObjectIdentifier(T.self)
        }

        func _unsafeGetRawValue() -> Any {
            return value
        }
    }

    private var storage: [AnyHashable: AnyBox] = [:]
    
    func hasKey<Key: Hashable>(_ key: Key) -> Bool {
        return storage.keys.contains(key)
    }

    // 存值（值或数组都可）
    func set<Key: Hashable, Value>(value: Value, forKey key: Key) {
        storage[key] = Box(value)
    }

    // 取值，Zero-cost 类型判断
    func getValue<Key: Hashable, Value>(forKey key: Key, type: Value.Type) -> Value? {
        guard let box = storage[key], box.typeID == ObjectIdentifier(Value.self) else {
            return nil
        }
        return unsafeBitCast(box._unsafeGetRawValue(), to: Value.self)
    }

    func remove<Key: Hashable>(forKey key: Key) {
        storage.removeValue(forKey: key)
    }

    func merge(_ other: ValueStorage) {
        storage.merge(other.storage) { $1 }
    }
}
