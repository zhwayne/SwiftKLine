//
//  RendererContext.swift
//  KLine
//
//  Created by iya on 2025/4/19.
//

import Foundation

/// 渲染器上下文
/// 包含渲染K线图所需的所有上下文信息
@MainActor
struct RendererContext<Item> {
    /// K线数据数组
    var items: [Item]
    /// 当前选中的K线索引
    var selectedIndex: Int?
    /// 当前可见的K线数据范围
    var visibleRange: Range<Int>
    /// 当前可见范围内的K线数据
    var visibleItems: [Item]
    /// 存储指标计算结果
    var visibleValues: [Any?]?
    /// K线样式管理器
    let candleStyle: CandleStyle
    /// 布局信息，包含位置计算相关的方法
    var layout: Layout
    /// 当前组的区域
    var groupFrame: CGRect
    /// 当前渲染的区域
    var viewPort: CGRect
    
    init(items: [Item], selectedIndex: Int? = nil, visibleRange: Range<Int>, visibleItems: [Item], visibleValues: [Any?]? = nil, candleStyle: CandleStyle, layout: Layout, groupFrame: CGRect, viewPort: CGRect) {
        self.items = items
        self.selectedIndex = selectedIndex
        self.visibleRange = visibleRange
        self.visibleItems = visibleItems
        self.visibleValues = visibleValues
        self.candleStyle = candleStyle
        self.layout = layout
        self.groupFrame = groupFrame
        self.viewPort = viewPort
    }
}

///// 渲染器上下文的扩展方法
//extension RendererContext {
//    
//    /// 获取指定键对应的可见范围内的数据
//    /// - Parameters:
//    ///   - key: 存储数据的键
//    ///   - type: 数据类型
//    /// - Returns: 可见范围内的数据切片，如果类型不匹配则返回nil
//    func visibleValue<T>(key: any Hashable, type: T.Type) -> ArraySlice<T>? {
//        guard let values = valueStorage[key] as? [T] else {
//            return nil
//        }
//        return values[visibleRange]
//    }
//}
