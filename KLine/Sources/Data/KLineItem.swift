//
//  KLineItem.swift
//  KLineDemo
//
//  Created by iya on 2024/10/31.
//

import UIKit

enum KLineTrend: Sendable {
    case rising, falling
    
    var color: CGColor {
        switch self {
        case .falling: return StyleManager.shared.candleStyle.fallingColor.cgColor
        default: return StyleManager.shared.candleStyle.risingColor.cgColor
        }
    }
}

/// 表示单个 K 线数据点。
public struct KLineItem: Equatable, Sendable {
    public let opening: Double      // 开盘价
    public let closing: Double      // 收盘价
    public let highest: Double      // 最高价
    public let lowest: Double       // 最低价
    public let volume: Double       // 成交量
    public let value: Double        // 成交额
    public let timestamp: Int       // 时间戳
    
    public init(
        opening: Double,
        closing: Double,
        highest: Double,
        lowest: Double,
        volume: Double,
        value: Double,
        timestamp: Int
    ) {
        self.opening = opening
        self.closing = closing
        self.highest = highest
        self.lowest = lowest
        self.volume = volume
        self.value = value
        self.timestamp = timestamp
    }
}

extension KLineItem {
    
    var trend: KLineTrend {
        if opening > closing { return .falling }
        return .rising
    }
}
