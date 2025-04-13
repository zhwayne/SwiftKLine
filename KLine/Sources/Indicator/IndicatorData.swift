//
//  IndicatorData.swift
//  KLineDemo
//
//  Created by iya on 2024/11/1.
//

import Foundation

protocol IndicatorValue: Sendable {
    var bounds: MetricBounds { get }
}

extension Double: IndicatorValue {
    var bounds: MetricBounds { MetricBounds(max: self, min: self) }
}

extension Int: IndicatorValue {
    var bounds: MetricBounds { MetricBounds(max: Double(self), min: Double(self)) }
}

/// 将 `KLineItem` 与其计算出的指标关联起来。
struct IndicatorData: Sendable {
    let item: KLineItem
    private var indicators: [IndicatorKey: IndicatorValue] = [:] // 存储不同指标的值
    
    /// 为特定的指标键设置指标值。
    ///
    /// - Parameters:
    ///   - value: 指标值。
    ///   - key: 指标键。
    mutating func setIndicator(value: IndicatorValue, forKey key: IndicatorKey) {
        indicators[key] = value
    }
    
    /// 获取特定指标键的指标值，指定类型。
    ///
    /// - Parameters:
    ///   - key: 指标键。
    ///   - type: 指标值的类型。
    /// - Returns: 指标值，若不存在或类型不匹配则返回 `nil`。
    func indicator(forKey key: IndicatorKey) -> IndicatorValue? {
        return indicators[key]
    }
    
    init(item: KLineItem) {
        self.item = item
    }
}

extension IndicatorData {
    
    mutating func merge(_ other: IndicatorData) {
        indicators.merge(other.indicators) { _, new in new }
    }
}

extension Array where Element == IndicatorData {
    
    mutating func merge(_ other: [Element]) {
        for idx in (0..<count) {
            self[idx].merge(other[idx])
        }
    }
}
