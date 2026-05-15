//
//  VOLCalculator.swift
//  KLineDemo
//
//  Created by iya on 2025/3/24.
//

import Foundation

struct VOLCalculator: KLineIndicatorCalculator {
    typealias Value = Double
    var id: SeriesKey {
        SeriesKey(indicatorID: IndicatorID("builtin.vol"), name: "VOL")
    }
    
    func calculate(for items: [any KLineItem]) -> [Double?] {
        return items.map(\.volume)
    }
    
}
