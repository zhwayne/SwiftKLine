//
//  RSICalculator.swift
//  KLineDemo
//
//  Created by iya on 2024/11/1.
//

import Foundation

/// 相对强弱指数 (RSI) 的计算器。
struct RSICalculator: IndicatorCalculator {
    
    typealias Result = Double
    let period: Int       // RSI 的周期
    var indicator: Indicator { .rsi }
    var id: some Hashable { Indicator.Key.rsi(period) }
    
    func calculate(for items: [any KLineItem]) -> [Double?] {
        guard period > 0 else { return Array(repeating: nil, count: items.count) }
        guard items.count > period else { return Array(repeating: nil, count: items.count) }
        
        // RSI 结果数组，前 `period` 天没有足够数据，RSI 值为 nil
        var rsiValues: [Double?] = Array(repeating: nil, count: items.count)
        var gains: [Double] = []
        var losses: [Double] = []
        
        // 初始化：计算第一个平均涨幅和平均跌幅
        for i in 1...period {
            let change = items[i].closing - items[i - 1].closing
            if change > 0 {
                gains.append(change)
                losses.append(0)
            } else {
                gains.append(0)
                losses.append(abs(change))
            }
        }
        
        var avgGain = gains.reduce(0, +) / Double(period)
        var avgLoss = losses.reduce(0, +) / Double(period)
        
        // 计算第一个 RSI 值
        if avgLoss == 0 {
            rsiValues[period] = 100.0  // 若无损失，RSI 为 100
        } else {
            let rs = avgGain / avgLoss
            rsiValues[period] = 100 - (100 / (1 + rs))
        }
        
        // 迭代计算后续的 RSI 值
        for i in (period + 1)..<items.count {
            let change = items[i].closing - items[i - 1].closing
            let gain = max(change, 0)
            let loss = max(-change, 0)
            
            // 平滑处理更新平均涨幅和平均跌幅
            avgGain = ((avgGain * Double(period - 1)) + gain) / Double(period)
            avgLoss = ((avgLoss * Double(period - 1)) + loss) / Double(period)
            
            // 计算 RSI
            if avgLoss == 0 {
                rsiValues[i] = 100.0
            } else {
                let rs = avgGain / avgLoss
                rsiValues[i] = 100 - (100 / (1 + rs))
            }
        }
        
        return rsiValues
    }
}
