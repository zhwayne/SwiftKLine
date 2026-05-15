//
//  KLineItem.swift
//  KLineDemo
//
//  Created by iya on 2024/10/31.
//

import UIKit

enum Trend: Sendable {
    case rising, falling
    
    @MainActor func color(using configuration: KLineConfiguration) -> UIColor {
        switch self {
        case .falling: return configuration.candleStyle.fallingColor
        case .rising: return configuration.candleStyle.risingColor
        }
    }
}

public protocol KLineItem: Equatable, Identifiable, Sendable {
    var open: Double { get }  // 开盘价
    var close: Double { get }  // 收盘价
    var high: Double { get }  // 最高价
    var low: Double  { get }  // 最低价
    var volume: Double  { get }  // 成交量
    var value: Double   { get }  // 成交额
    var timestamp: Int  { get }  // 时间戳(秒级)
}

extension KLineItem {
    
    public var id: Int { timestamp }
}

extension KLineItem {
    
    var dataBounds: ValueBounds {
        return ValueBounds(min: low, max: high)
    }
}

extension Collection where Element == any KLineItem {
    
    var lowerBoundItem: (Int, Element)? {
        guard let first = self.first else { return nil }
        var (idx, element) = (0, first)
        for (offset, item) in self.dropFirst().enumerated() {
            if item.low < element.low {
                (idx, element) = (offset + 1, item)
            }
        }
        return (idx, element)
    }
    
    var upperBoundItem: (Int, Element)? {
        guard let first = self.first else { return nil }
        var (idx, element) = (0, first)
        for (offset, item) in self.dropFirst().enumerated() {
            if item.high > element.high {
                (idx, element) = (offset + 1, item)
            }
        }
        return (idx, element)
    }
    
    var dataBounds: ValueBounds {
        return reduce(into: .empty) { partialResult, item in
            partialResult.merge(other: item.dataBounds)
        }
    }
}

extension KLineItem {
    
    var trend: Trend {
        if open > close { return .falling }
        return .rising
    }
}
