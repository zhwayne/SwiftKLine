//
//  IndicatorCalculator.swift
//  KLineDemo
//
//  Created by iya on 2024/11/1.
//

import Foundation

/// 指标计算协议
protocol IndicatorCalculator: Sendable {
    
    /// 指标的唯一键名。
    var key: IndicatorKey { get }
    
    /// 异步计算给定数据的指标值。
    ///
    /// - Parameter items: 数据项数组。
    /// - Returns: 指标值数组，若某个数据点无法计算则为 `nil`。
    func calculate(for items: [KLineItem]) -> [IndicatorValue?]
}
