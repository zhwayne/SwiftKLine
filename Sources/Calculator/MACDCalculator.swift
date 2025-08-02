//
//  MACDCalculator.swift
//  KLine
//
//  Created by iya on 2025/4/1.
//

import Foundation

/// 用于存储 MACD 相关指标值的结构体
struct MACDIndicatorValue: ValueBounds {
    let macd: Double     // MACD 线(DIF)
    let signal: Double   // 信号线(DEA)
    let histogram: Double // 柱状图(BAR)
    
    var min: Double { Swift.min(macd, signal, histogram) }
    var max: Double { Swift.max(macd, signal, histogram) }
}

/// MACD 计算器
struct MACDCalculator: IndicatorCalculator {
    
    typealias Result = MACDIndicatorValue
    let shortPeriod: Int = 12  // 短期 EMA 的周期（常用 12）
    let longPeriod: Int  = 26  // 长期 EMA 的周期（常用 26）
    let signalPeriod: Int = 9 // 信号线 EMA 的周期（常用 9）
    var indicator: Indicator { .macd }
    var id: some Hashable { Indicator.Key.macd }
    
    func calculate(for items: [any KLineItem]) -> [MACDIndicatorValue?] {
        // 至少需要足够的数据来计算长期 EMA
        guard items.count >= longPeriod else { return [] }
        
        // 计算短期 EMA 和长期 EMA
        let shortEMA = EMACalculator(period: shortPeriod).calculate(for: items) 
        let longEMA = EMACalculator(period: longPeriod).calculate(for: items) 
        
        // 计算MACD线：shortEMA - longEMA
        let macdLine = zip(shortEMA, longEMA).map { s, l -> Double? in
            guard let s = s, let l = l else { return nil }
            return s - l
        }
        
        // 计算信号线：对 MACD 线进行 EMA 计算
        // 找到从 longPeriod - 1 开始（即首个可能有 MACD 值的位置）
        var signalLine: [Double?] = Array(repeating: nil, count: items.count)
        let validMACDStart = longPeriod - 1
        // 确保有足够数据计算初始信号线（需要 signalPeriod 个值）
        if validMACDStart + signalPeriod <= items.count {
            var sum = 0.0
            for i in validMACDStart..<(validMACDStart + signalPeriod) {
                if let macdValue = macdLine[i] {
                    sum += macdValue
                }
            }
            let initialSignal = sum / Double(signalPeriod)
            signalLine[validMACDStart + signalPeriod - 1] = initialSignal
            
            let alphaSignal = 2.0 / (Double(signalPeriod) + 1.0)
            var previousSignal = initialSignal
            for i in (validMACDStart + signalPeriod)..<items.count {
                if let macdValue = macdLine[i] {
                    let signal = (macdValue - previousSignal) * alphaSignal + previousSignal
                    signalLine[i] = signal
                    previousSignal = signal
                }
            }
        }
        
        // 计算柱状图：MACD 线 - 信号线
        var histogram: [Double?] = Array(repeating: nil, count: items.count)
        for i in 0..<items.count {
            if let macd = macdLine[i], let signal = signalLine[i] {
                histogram[i] = 2 * (macd - signal)
            }
        }
        
        // 整合结果到 MACDIndicatorValue 中
        var macdValues: [MACDIndicatorValue?] = Array(repeating: nil, count: items.count)
        for i in 0..<items.count {
            if let macd = macdLine[i],
               let signal = signalLine[i],
               let hist = histogram[i] {
                macdValues[i] = MACDIndicatorValue(macd: macd, signal: signal, histogram: hist)
            }
        }
        
        return macdValues
    }
}
