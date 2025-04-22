//
//  IndicatorCalculator.swift
//  KLineDemo
//
//  Created by iya on 2024/11/1.
//

import Foundation

/// 指标计算协议
public protocol IndicatorCalculator {
    associatedtype Result
    associatedtype Identifier: Hashable
    
    var identifier: Identifier { get }
        
    /// 计算给定数据的指标值。
    ///
    /// - Parameter items: 数据项数组。
    /// - Returns: 指标值数组，若某个数据点无法计算则为 `nil`。
    func calculate(for items: [any KLineItem]) -> [Result?]
}

public struct NothingCalculator: IndicatorCalculator {
    public typealias Result = Void
    public typealias Identifier = String
    public let identifier: String
    public func calculate(for items: [any KLineItem]) -> [Void?] { return [] }
}

struct AnyIndicatorCalculator: IndicatorCalculator, @unchecked Sendable {
    
    typealias Result = Any
    typealias Identifier = AnyHashable
    
    private let _calculate: ([any KLineItem]) -> [Result?]
    
    let identifier: AnyHashable
        
    init<C: IndicatorCalculator>(_ base: C) {
        identifier = base.identifier
        _calculate = { items in
            base.calculate(for: items)
        }
    }
    
    @Sendable
    func calculate(for items: [any KLineItem]) -> [Result?] {
        return _calculate(items)
    }
}

extension IndicatorCalculator {
    
    func eraseToAnyCalculator() -> AnyIndicatorCalculator {
        AnyIndicatorCalculator(self)
    }
}
