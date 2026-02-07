//
//  IndicatorSeriesStore.swift
//  SwiftKLine
//
//  Created by iya on 2026/2/7.
//

import Foundation

/// 指标序列的统一存储。
///
/// 通过 `Indicator.Key` 作为主索引，按 value family 分桶，避免新增指标时创建额外 Key 类型。
struct IndicatorSeriesStore {
    /// 标量指标 bucket。
    var scalarSeries: [Indicator.Key: ContiguousArray<Double?>] = [:]
    /// BOLL 指标 bucket。
    var bollSeries: [Indicator.Key: ContiguousArray<BOLLIndicatorValue?>] = [:]
    /// MACD 指标 bucket。
    var macdSeries: [Indicator.Key: ContiguousArray<MACDIndicatorValue?>] = [:]

    /// 将另一个局部存储合并到当前存储。
    ///
    /// 语义为“同 key 覆盖”，适用于并发计算后归并结果。
    mutating func merge(_ other: IndicatorSeriesStore) {
        scalarSeries.merge(other.scalarSeries) { _, new in new }
        bollSeries.merge(other.bollSeries) { _, new in new }
        macdSeries.merge(other.macdSeries) { _, new in new }
    }
}
