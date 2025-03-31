//
//  EMACalcularot.swift
//  KLineDemo
//
//  Created by iya on 2024/11/6.
//

import Foundation

/// 指数移动平均线 (EMA) 的计算器。
struct EMACalculator: IndicatorCalculator {
    
    let period: Int       // 移动平均线的周期
    
    var key: IndicatorKey {
        return .ema(period: period)
    }
    
    func calculate(for items: [KLineItem]) -> [IndicatorValue?] {
        guard period > 0 && items.count >= period else {
            return []
        }

        var emaValues: [Double?] = Array(repeating: nil, count: items.count)
        
        // 计算平滑系数 α
        let alpha = 2.0 / (Double(period) + 1.0)
        
        // 计算初始 EMA（简单移动平均线作为初始值）
        var sum = 0.0
        for i in 0..<period {
            sum += items[i].closing
        }
        
        // 第一个 EMA 值（简单平均作为基础）
        let initialEMA = sum / Double(period)
        emaValues[period - 1] = initialEMA
        
        // 从第 `period` 个位置开始计算 EMA
        var previousEMA = initialEMA
        for i in period..<items.count {
            let currentPrice = items[i].closing
            let ema = (currentPrice - previousEMA) * alpha + previousEMA
            emaValues[i] = ema
            previousEMA = ema
        }
        
        return emaValues
    }
}
