//
//  KLineMetricBounds.swift
//  SwiftKLine
//
//  Created by iya on 2024/10/31.
//

import Foundation

/// 表示特定指标的最大值和最小值。
public struct KLineMetricBounds: KLineValueBounds {
    public var min: Double      // 最小值
    public var max: Double      // 最大值
    
    public init(min: Double, max: Double) {
        self.min = min
        self.max = max
    }
    
    public init(range: ClosedRange<Double>) {
        self.min = range.lowerBound
        self.max = range.upperBound
    }
    
    public static var empty: Self {
        KLineMetricBounds(
            min: Double(Int.max),
            max: Double(Int.min)
        )
    }
}

extension KLineMetricBounds {
    /// 最大值与最小值的距离。
    var distance: Double { max - min }
    
    /// 合并另一个 `KLineMetricBounds`，更新最大值和最小值。
    ///
    /// - Parameter other: 需要合并的另一个 `KLineMetricBounds`。
    mutating func merge(other bounds: KLineMetricBounds) {
        max = Swift.max(max, bounds.max)
        min = Swift.min(min, bounds.min)
    }
    
    func merging(other bounds: KLineMetricBounds) -> KLineMetricBounds {
        let max = Swift.max(max, bounds.max)
        let min = Swift.min(min, bounds.min)
        return KLineMetricBounds(min: min, max: max)
    }
}
