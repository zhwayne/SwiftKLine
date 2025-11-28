//
//  WMACalculator.swift
//  SwiftKLine
//
//  Created by iya on 2024/11/1.
//

import Foundation

/// 加权移动平均线 (WMA) 计算器，近期数据权重大、远期数据权重小。
struct WMACalculator: IndicatorCalculator {
    
    typealias Result = Double
    let period: Int
    var indicator: Indicator { .wma }
    var id: some Hashable { Indicator.Key.wma(period) }
    
    func calculate(for items: [any KLineItem]) -> [Double?] {
        guard period > 0 else { return Array(repeating: nil, count: items.count) }
        
        var result = [Double?](repeating: nil, count: items.count)
        guard items.count >= period else { return result }
        
        let weightSum = Double(period * (period + 1) / 2)
        
        for index in (period - 1)..<items.count {
            var weightedSum = 0.0
            for offset in 0..<period {
                let weight = Double(offset + 1)
                let priceIndex = index - period + 1 + offset
                weightedSum += items[priceIndex].closing * weight
            }
            result[index] = weightedSum / weightSum
        }
        
        return result
    }
}
