//
//  MACalculator.swift
//  KLineDemo
//
//  Created by iya on 2024/11/1.
//

import Foundation

/// 简单移动平均线 (SMA) 的计算器。
struct MACalculator: KLineIndicatorCalculator {
    typealias Value = Double
    let period: Int       // 移动平均线的周期
    var id: SeriesKey {
        SeriesKey(indicatorID: IndicatorID("builtin.ma"), name: "MA", parameters: ["period": "\(period)"])
    }
    
    func calculate(for items: [any KLineItem]) -> [Double?] {
        guard period > 0 else { return Array(repeating: nil, count: items.count) }
        guard items.count >= period else { return Array(repeating: nil, count: items.count) }
        
        var result = [Double?](repeating: nil, count: items.count)
        var sum: Double = 0
        
        for i in 0..<items.count {
            sum += items[i].close
            
            if i >= period {
                sum -= items[i - period].close
            }
            
            if i >= period - 1 {
                result[i] = sum / Double(period)
            }
        }
        
        return result
    }
    
}
