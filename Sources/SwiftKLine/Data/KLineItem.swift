//
//  KLineItem.swift
//  KLineDemo
//
//  Created by iya on 2024/10/31.
//

import UIKit

enum KLineTrend: Sendable {
    case rising, falling
    
    @MainActor var color: UIColor {
        switch self {
        case .falling: return KLineConfig.default.candleStyle.fallingColor
        default: return KLineConfig.default.candleStyle.risingColor
        }
    }
}

public protocol KLineItem: Equatable, Identifiable, Sendable {
    var opening: Double { get }  // 开盘价
    var closing: Double { get }  // 收盘价
    var highest: Double { get }  // 最高价
    var lowest: Double  { get }  // 最低价
    var volume: Double  { get }  // 成交量
    var value: Double   { get }  // 成交额
    var timestamp: Int  { get }  // 时间戳(秒级)
}

extension KLineItem {
    
    public var id: Int { timestamp }
}

extension KLineItem {
    
    var dataBounds: MetricBounds {
        return MetricBounds(min: lowest, max: highest)
    }
}

extension Collection where Element == any KLineItem {
    
    var lowerBoundItem: (Int, Element)? {
        if isEmpty { return nil }
        var (idx, element) = (0, self.first!)
        for (offset, item) in self.dropFirst().enumerated() {
            if item.lowest < element.lowest {
                (idx, element) = (offset + 1, item)
            }
        }
        return (idx, element)
    }
    
    var upperBoundItem: (Int, Element)? {
        if isEmpty { return nil }
        var (idx, element) = (0, self.first!)
        for (offset, item) in self.dropFirst().enumerated() {
            if item.highest > element.highest {
                (idx, element) = (offset + 1, item)
            }
        }
        return (idx, element)
    }
    
    var dataBounds: MetricBounds {
        return reduce(into: .empty) { partialResult, item in
            partialResult.merge(other: item.dataBounds)
        }
    }
}

//struct AnyKLineItem: KLineItem {
//    var opening: Double
//    var closing: Double
//    var highest: Double
//    var lowest: Double
//    var volume: Double
//    var value: Double
//    var timestamp: Int
//    
//    init<I: KLineItem>(_ base: I) {
//        opening = base.opening
//        closing = base.closing
//        highest = base.highest
//        lowest = base.lowest
//        volume = base.volume
//        value = base.value
//        timestamp = base.timestamp
//    }
//}

extension KLineItem {
    
    var trend: KLineTrend {
        if opening > closing { return .falling }
        return .rising
    }
}
