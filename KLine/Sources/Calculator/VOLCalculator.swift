//
//  VOLCalculator.swift
//  KLineDemo
//
//  Created by iya on 2025/3/24.
//

import Foundation

struct VOLCalculator: IndicatorCalculator {
    
    typealias Result = Double
    var indicator: Indicator { .vol }
    var id: some Hashable { Indicator.Key.vol }
    
    func calculate(for items: [any KLineItem]) -> [Double?] {
        return items.map(\.volume)
    }
}
