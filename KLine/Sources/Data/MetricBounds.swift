//
//  MetricBounds.swift
//  KLine
//
//  Created by iya on 2024/10/31.
//

import Foundation

/// 表示特定指标的最大值和最小值。
struct MetricBounds: ValueBounds {
    var min: Double      // 最小值
    var max: Double      // 最大值
    
    init(min: Double, max: Double) {
        self.min = min
        self.max = max
    }
    
    init(range: ClosedRange<Double>) {
        self.min = range.lowerBound
        self.max = range.upperBound
    }
    
    static var empty: Self {
        MetricBounds(
            min: .greatestFiniteMagnitude,
            max: -.greatestFiniteMagnitude
        )
    }
}

extension MetricBounds {
    /// 最大值与最小值的距离。
    var distance: Double { max - min }
    
    /// 合并另一个 `MetricBounds`，更新最大值和最小值。
    ///
    /// - Parameter other: 需要合并的另一个 `MetricBounds`。
    mutating func merge(other bounds: MetricBounds) {
        max = Swift.max(max, bounds.max)
        min = Swift.min(min, bounds.min)
    }
}
