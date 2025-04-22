//
//  VOLCalculator.swift
//  KLineDemo
//
//  Created by iya on 2025/3/24.
//

import Foundation

struct VOLCalculator: IndicatorCalculator {
    typealias Identifier = Indicator.Key
    typealias Result = Double
        
    var identifier: Indicator.Key { .vol }
    
    func calculate(for items: [any KLineItem]) -> [Double?] {
        return items.map(\.volume)
    }
}
