//
//  RendererContext.swift
//  KLine
//
//  Created by iya on 2025/4/19.
//

import Foundation

/// 渲染器上下文
/// 包含渲染K线图所需的所有上下文信息
@MainActor public final class RendererContext<Item> {
    /// 存储指标计算结果
    let valueStorage: ValueStorage
    /// K线数据数组
    public let items: [Item]
    /// 当前可见的K线数据范围
    public let visibleRange: Range<Int>
    /// 布局信息，包含位置计算相关的方法
    public let layout: Layout
    /// 当前长按手势坐标位置
    public let location: CGPoint?
    /// 当前长按手势坐标位置对应的item下标
    public let currentIndex: Int
    /// 当前组的区域
    public internal(set) var groupFrame: CGRect = .zero
    /// 当前渲染的区域
    public internal(set) var viewPort: CGRect = .zero
    /// 图例的位置
    public internal(set) var legendFrame: CGRect = .zero
    /// 图例的文本
    public internal(set) var legendText: NSAttributedString?
    
    init(
        valueStorage: ValueStorage,
        items: [Item],
        visibleRange: Range<Int>,
        layout: Layout,
        location: CGPoint?,
        selectedIndex: Int?
    ) {
        self.valueStorage = valueStorage
        self.items = items
        self.visibleRange = visibleRange
        self.layout = layout
        self.location = location
        self.currentIndex = selectedIndex ?? visibleRange.upperBound - 1
    }
}

/// 渲染器上下文的扩展方法
extension RendererContext {
    
    public var visibleItems: ArraySlice<Item> {
        if items.isEmpty { return [] }
        return items[visibleRange]
    }
    
    /// 获取指定键对应的可见范围内的数据
    /// - Parameters:
    ///   - key: 存储数据的键
    ///   - type: 数据类型
    /// - Returns: 可见范围内的数据切片，如果类型不匹配则返回nil
    public func visibleValues<Key: Hashable, T>(forKey key: Key, valueType: T.Type) -> ArraySlice<T>? {
        return values(forKey: key, valueType: valueType)?[visibleRange]
    }
    
    public func values<Key: Hashable, T>(forKey key: Key, valueType type: T.Type) -> Array<T>? {
        if let values = valueStorage.getValue(forKey: key, type: [T].self) {
            return values
        }
        return nil
    }
}
