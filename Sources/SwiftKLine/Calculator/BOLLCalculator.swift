//
//  BOLLCalculator.swift
//  SwiftKLine
//
//  Created by W Zh on 2025/8/6.
//

import Foundation

struct BOLLIndicatorValue: ValueBounds {
    let middle: Double  // 中轨
    let upper: Double   // 上轨
    let lower: Double   // 下轨
    
    var min: Double { Swift.min(lower, middle, upper) }
    var max: Double { Swift.max(lower, middle, upper) }
}

/// BOLL 指标计算器
struct BOLLCalculator: IndicatorCalculator {
    
    typealias Result = BOLLIndicatorValue
    var indicator: Indicator { .boll }
    var id: some Hashable { Indicator.Key.boll }
    
    /// 计算周期（常用 20）
    let period: Int = 20
    /// 带宽系数（常用 2.0）
    let k: Double = 2.0

    func calculate(for items: [any KLineItem]) -> [Result?] {
        guard period > 0, items.count >= period else {
            return Array(repeating: nil, count: items.count)
        }
        
        var results: [Result?] = Array(repeating: nil, count: items.count)
        
        for i in (period - 1)..<items.count {
            let window = items[(i - period + 1)...i]
            
            // 收盘价
            let closes = window.map { $0.closing }
            
            // 中轨 (MA)
            let avg = closes.reduce(0, +) / Double(period)
            
            // 标准差
            let variance = closes.reduce(0) { $0 + pow($1 - avg, 2) } / Double(period)
            let stdDev = sqrt(variance)
            
            // 上轨 & 下轨
            let upper = avg + k * stdDev
            let lower = avg - k * stdDev
            
            results[i] = Result(middle: avg, upper: upper, lower: lower)
        }
        
        return results
    }
}
