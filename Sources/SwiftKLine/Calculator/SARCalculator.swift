//
//  SARCalculator.swift
//  SwiftKLine
//
//  Created by zhwayne on 2025/8/7.
//

import Foundation

struct SARCalculator: IndicatorCalculator {
    typealias Value = Double
    var id: SeriesKey {
        SeriesKey(indicatorID: IndicatorID("builtin.sar"), name: "SAR")
    }
    
    /// 初始加速因子
    private let afStart: Double
    /// 加速因子增量
    private let afStep: Double
    /// 加速因子最大值
    private let afMax: Double
    
    public init(
        afStart: Double = 0.02,
        afStep: Double = 0.02,
        afMax: Double = 0.2
    ) {
        self.afStart = afStart
        self.afStep = afStep
        self.afMax = afMax
    }
    
    public func calculate(for items: [any ChartItem]) -> [Double?] {
        guard items.count >= 2 else {
            return Array(repeating: nil, count: items.count)
        }
        
        var results: [Double?] = Array(repeating: nil, count: items.count)
        
        // 初始趋势判断
        var isUpTrend = items[1].close > items[0].close
        
        // 初始极值点 EP（上涨取最高价，下跌取最低价）
        var ep = isUpTrend ? items[0].high : items[0].low
        
        // 初始 SAR（上一根 K 的最低价 / 最高价）
        var sar = isUpTrend ? items[0].low : items[0].high
        
        var af = afStart
        
        for i in 1..<items.count {
            sar = sar + af * (ep - sar)
            
            if isUpTrend {
                // SAR 不能高于前两天最低价
                sar = min(sar, items[i-1].low, items[i-2 >= 0 ? i-2 : i-1].low)
            } else {
                // SAR 不能低于前两天最高价
                sar = max(sar, items[i-1].high, items[i-2 >= 0 ? i-2 : i-1].high)
            }
            
            // 保存结果
            results[i] = sar
            
            // 更新趋势和参数
            if isUpTrend {
                if items[i].high > ep {
                    ep = items[i].high
                    af = min(af + afStep, afMax)
                }
                // 趋势反转
                if items[i].low < sar {
                    isUpTrend = false
                    sar = ep
                    ep = items[i].low
                    af = afStart
                }
            } else {
                if items[i].low < ep {
                    ep = items[i].low
                    af = min(af + afStep, afMax)
                }
                // 趋势反转
                if items[i].high > sar {
                    isUpTrend = true
                    sar = ep
                    ep = items[i].high
                    af = afStart
                }
            }
        }
        
        return results
    }
    
}
