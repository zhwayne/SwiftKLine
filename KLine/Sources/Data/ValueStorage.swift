//
//  ValueStorage.swift
//  KLine
//
//  Created by iya on 2024/11/1.
//

import Foundation

protocol ValueBounds: Sendable {
    var min: Double { get }
    var max: Double { get }
}

struct ValueStorage: @unchecked Sendable {
    private var storage: [AnyHashable: Any] = [:]
    
    subscript<Key: Hashable>(key: Key) -> Any? {
        get { storage[key] }
        set { storage[key] = newValue }
    }
    
    mutating func merge(_ other: ValueStorage) {
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
