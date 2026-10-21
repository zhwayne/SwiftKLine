//
//  SARCalculator.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2025/08/07.
//

import Foundation

/// Computes parabolic stop-and-reverse values with explicit acceleration parameters.
///
/// The first candle is nil. A reversal emits the reset SAR at the tracked trend extreme, and invalid acceleration settings return nil.
public struct SARCalculator: IndicatorCalculator {
    /// A scalar SAR price at each candle index.
    public typealias Value = Double
    /// The stable series key, including configured calculation parameters.
    public var id: SeriesKey {
        .sar(afStart: afStart, afStep: afStep, afMax: afMax)
    }
    
    /// The finite, positive acceleration factor used initially and after a reversal.
    public let afStart: Double
    /// The finite, nonnegative acceleration increment when a new trend extreme is found.
    public let afStep: Double
    /// The finite acceleration cap; it must be at least afStart.
    public let afMax: Double
    
    /// Stores calculator parameters; validity is checked when calculating, rather than by the initializer.
    public init(
        afStart: Double = 0.02,
        afStep: Double = 0.02,
        afMax: Double = 0.2
    ) {
        self.afStart = afStart
        self.afStep = afStep
        self.afMax = afMax
    }
    
    /// Calculates an input-aligned output array.
    ///
    /// The first candle is nil. A reversal emits the reset SAR at the tracked trend extreme, and invalid acceleration settings return nil.
    public func calculate(for items: [any ChartItem]) -> [Double?] {
        guard items.count >= 2, afStart.isFinite, afStep.isFinite, afMax.isFinite,
              afStart > 0, afStep >= 0, afMax >= afStart else {
            return Array(repeating: nil, count: items.count)
        }
        
        var results: [Double?] = Array(repeating: nil, count: items.count)
        
        // Infer the initial trend from the first two closes.
        var isUpTrend = items[1].close > items[0].close
        
        // Seed the extreme point from the initial trend.
        var ep = isUpTrend ? items[0].high : items[0].low
        
        // Seed SAR from the first candle’s low or high according to trend.
        var sar = isUpTrend ? items[0].low : items[0].high
        
        var af = afStart
        
        for i in 1..<items.count {
            if i & 1023 == 0, Task.isCancelled { return results }
            sar = sar + af * (ep - sar)
            
            if isUpTrend {
                // Clamp a rising SAR below the previous two lows.
                sar = min(sar, items[i-1].low, items[i-2 >= 0 ? i-2 : i-1].low)
            } else {
                // Clamp a falling SAR above the previous two highs.
                sar = max(sar, items[i-1].high, items[i-2 >= 0 ? i-2 : i-1].high)
            }
            
            // Update the trend extreme and acceleration state.
            if isUpTrend {
                if items[i].high > ep {
                    ep = items[i].high
                    af = min(af + afStep, afMax)
                }
                // Reset trend state on reversal.
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
                // Reset trend state on reversal.
                if items[i].high > sar {
                    isUpTrend = true
                    sar = ep
                    ep = items[i].high
                    af = afStart
                }
            }
            // Emit the reset extreme on the reversal candle, not the pre-reversal candidate.
            results[i] = sar
        }
        
        return results
    }
    
}
