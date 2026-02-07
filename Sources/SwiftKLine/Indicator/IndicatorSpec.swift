//
//  IndicatorSpec.swift
//  SwiftKLine
//
//  Created by iya on 2026/2/7.
//

import Foundation

/// 指标值的存储家族，用于决定结果写入哪个 bucket。
@MainActor
enum IndicatorValueFamily {
    case scalar
    case boll
    case macd
}

/// 指标的单一描述入口。
///
/// 一个 spec 同时负责：
/// 1. 构造该指标所需 calculators；
/// 2. 构造默认 renderer。
@MainActor
protocol IndicatorSpec {
    /// 对应的指标类型。
    var indicator: Indicator { get }
    /// 对应的值家族（用于存储分桶）。
    var valueFamily: IndicatorValueFamily { get }

    /// 根据配置构建该指标 calculators。
    func makeCalculators(configuration: KLineConfiguration) -> [any IndicatorCalculator]
    /// 根据配置构建该指标 renderer。
    func makeRenderer(configuration: KLineConfiguration) -> (any Renderer)?
}
