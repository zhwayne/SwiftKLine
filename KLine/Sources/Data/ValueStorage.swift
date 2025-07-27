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

///// 将 `KLineItem` 与其计算出的指标关联起来。
//struct IndicatorData: @unchecked Sendable {
//    let item: any KLineItem
//    private var indicators: [AnyHashable: IndicatorValue] = [:] // 存储不同指标的值
//
//    /// 为特定的指标键设置指标值。
//    ///
//    /// - Parameters:
//    ///   - value: 指标值。
//    ///   - key: 指标键。
//    mutating func setIndicator(value: IndicatorValue, forKey key: any Hashable) {
//        indicators[AnyHashable(key)] = value
//    }
//
//    /// 获取特定指标键的指标值，指定类型。
//    ///
//    /// - Parameters:
//    ///   - key: 指标键。
//    ///   - type: 指标值的类型。
//    /// - Returns: 指标值，若不存在或类型不匹配则返回 `nil`。
//    func indicator(forKey key: any Hashable) -> IndicatorValue? {
//        return indicators[AnyHashable(key)]
//    }
//
//    init(item: any KLineItem) {
//        self.item = item
//    }
//}
//
//extension IndicatorData {
//
//    mutating func merge(_ other: IndicatorData) {
//        indicators.merge(other.indicators) { _, new in new }
//    }
//}
//
//extension Array where Element == IndicatorData {
//
//    mutating func merge(_ other: [Element]) {
//        for idx in (0..<count) {
//            self[idx].merge(other[idx])
//        }
//    }
//}
