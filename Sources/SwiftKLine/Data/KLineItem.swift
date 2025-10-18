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

extension KLineItem {
    
    var trend: KLineTrend {
        if opening > closing { return .falling }
        return .rising
    }
    
    func asInterpolatedItem() -> InterpolatedKLineItem {
        InterpolatedKLineItem(copying: self)
    }
    
    func interpolated(to other: some KLineItem, progress: Double) -> InterpolatedKLineItem {
        let from = InterpolatedKLineItem(copying: self)
        let to = InterpolatedKLineItem(copying: other)
        return InterpolatedKLineItem.interpolate(from: from, to: to, progress: progress)
    }
}

struct InterpolatedKLineItem: KLineItem, Sendable {
    let opening: Double
    let closing: Double
    let highest: Double
    let lowest: Double
    let volume: Double
    let value: Double
    let timestamp: Int
}

extension InterpolatedKLineItem {
    static func makeBaseline(from item: any KLineItem) -> InterpolatedKLineItem {
        InterpolatedKLineItem(
            opening: item.opening,
            closing: item.opening,
            highest: item.opening,
            lowest: item.opening,
            volume: 0,
            value: 0,
            timestamp: item.timestamp
        )
    }

    init(copying item: any KLineItem) {
        self.init(
            opening: item.opening,
            closing: item.closing,
            highest: item.highest,
            lowest: item.lowest,
            volume: item.volume,
            value: item.value,
            timestamp: item.timestamp
        )
    }
}

extension InterpolatedKLineItem: AnimatableValue {
    static func interpolate(from: InterpolatedKLineItem, to: InterpolatedKLineItem, progress: Double) -> InterpolatedKLineItem {
        let clamped = min(max(progress, 0), 1)
        func lerp(_ a: Double, _ b: Double) -> Double {
            a + (b - a) * clamped
        }
        return InterpolatedKLineItem(
            opening: lerp(from.opening, to.opening),
            closing: lerp(from.closing, to.closing),
            highest: lerp(from.highest, to.highest),
            lowest: lerp(from.lowest, to.lowest),
            volume: lerp(from.volume, to.volume),
            value: lerp(from.value, to.value),
            timestamp: to.timestamp
        )
    }
}
