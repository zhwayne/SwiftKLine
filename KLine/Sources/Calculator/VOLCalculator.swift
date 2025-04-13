//
//  VOLCalculator.swift
//  KLineDemo
//
//  Created by iya on 2025/3/24.
//

import Foundation

struct VOLCalculator: IndicatorCalculator {
        
    var key: IndicatorKey { .vol }
    
    func calculate(for items: [KLineItem]) -> [IndicatorValue?] {
        return items.map(\.volume)
    }
}
