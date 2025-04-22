//
//  EMACalcularot.swift
//  KLineDemo
//
//  Created by iya on 2024/11/6.
//

import Foundation

/// 指数移动平均线 (EMA) 的计算器。
struct EMACalculator: IndicatorCalculator {
    typealias Identifier = Indicator.Key
    typealias Result = Double
    
    let period: Int       // 移动平均线的周期
    
    var identifier: Indicator.Key {
        return .ema(period: period)
    }
    
    func calculate(for items: [any KLineItem]) -> [Double?] {
        guard period > 0 && items.count >= period else {
            return []
        }

        var emaValues: [Double?] = Array(repeating: nil, count: items.count)
        
        // 计算平滑系数 α
        let alpha = 2.0 / (Double(period) + 1.0)
        
        // 计算初始 EMA（简单移动平均线作为初始值）
        var sum = 0.0
        
        var previousEMA = 0.0
        for i in 0..<items.count {
            sum += items[i].closing
            if i >= period {
                // 从第 `period` 个位置开始计算 EMA
                let currentPrice = items[i].closing
                let ema = (currentPrice - previousEMA) * alpha + previousEMA
                emaValues[i] = ema
                previousEMA = ema
            } else {
                // 前 i+1 个数据的平均
                let ema = sum / Double(i + 1)
                emaValues[i] = ema
                previousEMA = ema
            }
        }
        
        return emaValues
    }
}
