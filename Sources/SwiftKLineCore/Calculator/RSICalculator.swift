//
//  RSICalculator.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2024/11/01.
//

import Foundation

/// Computes relative strength using Wilder-smoothed average gains and losses.
///
/// The first period outputs are nil. No average loss produces RSI 100, including an entirely flat window.
public struct RSICalculator: IndicatorCalculator {
    /// A scalar RSI value, normally in the range zero through one hundred.
    public typealias Value = Double
    /// The number of candles in the calculation period; positive values are required.
    public let period: Int
    /// Stores calculator parameters; validity is checked when calculating, rather than by the initializer.
    public init(period: Int) { self.period = period }
    /// The stable series key, including configured calculation parameters.
    public var id: SeriesKey {
        SeriesKey(indicatorID: IndicatorID("builtin.rsi"), name: "RSI", parameters: ["period": "\(period)"])
    }
    
    /// Calculates an input-aligned output array.
    ///
    /// The first period outputs are nil. No average loss produces RSI 100, including an entirely flat window.
    public func calculate(for items: [any ChartItem]) -> [Double?] {
        guard period > 0 else { return Array(repeating: nil, count: items.count) }
        guard items.count > period else { return Array(repeating: nil, count: items.count) }
        
        // The first period candles do not have enough changes to seed RSI.
        var rsiValues: [Double?] = Array(repeating: nil, count: items.count)
        var gainSum = 0.0
        var lossSum = 0.0
        
        // Seed the first average gain and loss from consecutive close changes.
        for i in 1...period {
            let change = items[i].close - items[i - 1].close
            gainSum += max(change, 0)
            lossSum += max(-change, 0)
        }
        var avgGain = gainSum / Double(period)
        var avgLoss = lossSum / Double(period)

        // Calculate the first available RSI value.
        if avgLoss == 0 {
            rsiValues[period] = 100.0  // No average loss yields RSI 100.
        } else {
            let rs = avgGain / avgLoss
            rsiValues[period] = 100 - (100 / (1 + rs))
        }
        
        // Advance the smoothed RSI through the remaining candles.
        for i in (period + 1)..<items.count {
            if i & 1023 == 0, Task.isCancelled { return rsiValues }
            let change = items[i].close - items[i - 1].close
            let gain = max(change, 0)
            let loss = max(-change, 0)
            
            // Apply Wilder smoothing to average gains and losses.
            avgGain = ((avgGain * Double(period - 1)) + gain) / Double(period)
            avgLoss = ((avgLoss * Double(period - 1)) + loss) / Double(period)
            
            // Convert the relative-strength ratio into RSI.
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
