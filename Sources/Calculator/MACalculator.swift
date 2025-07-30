//
//  MACalculator.swift
//  KLineDemo
//
//  Created by iya on 2024/11/1.
//

import Foundation

/// 简单移动平均线 (SMA) 的计算器。
struct MACalculator: IndicatorCalculator {
    
    typealias Result = Double
    let period: Int       // 移动平均线的周期
    var indicator: Indicator { .ma }
    var id: some Hashable { Indicator.Key.ma(period) }
    
    func calculate(for items: [any KLineItem]) -> [Double?] {
        guard period > 0 && items.count >= period else {
            return []
        }
        
        var result = [Double?](repeating: nil, count: items.count)
        var sum: Double = 0
        
        for i in 0..<items.count {
            sum += items[i].closing
            
            if i >= period {
                sum -= items[i - period].closing
            }
            
            if i >= period - 1 {
                result[i] = sum / Double(period)
            }
        }
        
        return result
    }
}
