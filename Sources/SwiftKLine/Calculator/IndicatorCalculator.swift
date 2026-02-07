//
//  IndicatorCalculator.swift
//  KLineDemo
//
//  Created by iya on 2024/11/1.
//

import Foundation

public protocol ValueBounds {
    var min: Double { get }
    var max: Double { get }
}

/// 指标计算协议
protocol IndicatorCalculator: Sendable {
    associatedtype Result
    associatedtype Identifier: Hashable
    
    var indicator: Indicator { get }
    /// 指标结果在存储中的主键。
    var key: Indicator.Key { get }
    var id: Identifier { get }
        
    /// 计算给定数据的指标值。
    ///
    /// - Parameter items: 数据项数组。
    /// - Returns: 指标值数组，若某个数据点无法计算则为 `nil`。
    func calculate(for items: [any KLineItem]) -> [Result?]
    
    /// 计算并返回该指标对应的局部存储结果。
    func calculateStore(items: [any KLineItem]) -> IndicatorSeriesStore
}

extension IndicatorCalculator {
    
    func calculate<T>(for items: [any KLineItem], asType type: T.Type) -> [T?]? {
        let values = calculate(for: items)
        let result = values as? [T?]
        return result
    }
}

extension IndicatorCalculator where Result == Double {
    func calculateStore(items: [any KLineItem]) -> IndicatorSeriesStore {
        var store = IndicatorSeriesStore()
        store.scalarSeries[key] = ContiguousArray(calculate(for: items))
        return store
    }
}

extension IndicatorCalculator where Result == BOLLIndicatorValue {
    func calculateStore(items: [any KLineItem]) -> IndicatorSeriesStore {
        var store = IndicatorSeriesStore()
        store.bollSeries[key] = ContiguousArray(calculate(for: items))
        return store
    }
}

extension IndicatorCalculator where Result == MACDIndicatorValue {
    func calculateStore(items: [any KLineItem]) -> IndicatorSeriesStore {
        var store = IndicatorSeriesStore()
        store.macdSeries[key] = ContiguousArray(calculate(for: items))
        return store
    }
}
