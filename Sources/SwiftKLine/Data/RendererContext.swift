//
//  RendererContext.swift
//  SwiftKLine
//
//  Created by iya on 2025/4/19.
//

import UIKit

/// 渲染器上下文
/// 包含渲染K线图所需的所有上下文信息
@MainActor public final class RendererContext<Item> {
    /// 存储指标计算结果
    let indicatorSeriesStore: IndicatorSeriesStore
    /// K线数据数组
    public let items: [Item]
    /// 样式配置
    public let configuration: KLineConfiguration
    /// 当前可见的K线数据范围
    public let visibleRange: Range<Int>
    /// 布局信息，包含位置计算相关的方法
    public let layout: KLineLayout
    /// 当前长按手势坐标位置
    public let location: CGPoint?
    /// 当前激活的item下标
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
        indicatorSeriesStore: IndicatorSeriesStore,
        items: [Item],
        configuration: KLineConfiguration,
        visibleRange: Range<Int>,
        layout: KLineLayout,
        location: CGPoint?,
        selectedIndex: Int?
    ) {
        self.indicatorSeriesStore = indicatorSeriesStore
        self.items = items
        self.configuration = configuration
        self.visibleRange = visibleRange
        self.layout = layout
        self.location = location
        self.currentIndex = selectedIndex ?? visibleRange.upperBound - 1
    }
}

/// 渲染器上下文的扩展方法
extension RendererContext {
    
    public var visibleItems: ArraySlice<Item> {
        guard !items.isEmpty,
              visibleRange.lowerBound >= 0,
              visibleRange.upperBound <= items.count else {
            return []
        }
        return items[visibleRange]
    }
    
    /// 通用可见区间切片工具。
    /// 仅负责边界校验和切片，不关心具体指标类型。
    private func visibleValues<T>(from values: ContiguousArray<T>?) -> ArraySlice<T>? {
        guard let values else { return nil }
        // 确保 visibleRange 在数组有效范围内
        guard !values.isEmpty,
              visibleRange.lowerBound >= 0,
              visibleRange.upperBound <= values.count else {
            return nil
        }
        return values[visibleRange]
    }
    
    /// 读取标量指标全量序列。
    func scalarValues(for key: Indicator.Key) -> ContiguousArray<Double?>? {
        indicatorSeriesStore.scalarSeries[key]
    }
    
    /// 读取标量指标可见区间序列。
    func visibleScalarValues(for key: Indicator.Key) -> ArraySlice<Double?>? {
        visibleValues(from: scalarValues(for: key))
    }
    
    /// 读取 BOLL 指标全量序列。
    func bollValues(for key: Indicator.Key = .boll(period: 20, k: 2.0)) -> ContiguousArray<BOLLIndicatorValue?>? {
        indicatorSeriesStore.bollSeries[key]
    }
    
    /// 读取 BOLL 指标可见区间序列。
    func visibleBollValues(for key: Indicator.Key = .boll(period: 20, k: 2.0)) -> ArraySlice<BOLLIndicatorValue?>? {
        visibleValues(from: bollValues(for: key))
    }
    
    /// 读取 MACD 指标全量序列。
    func macdValues(for key: Indicator.Key = .macd(shortPeriod: 12, longPeriod: 26, signalPeriod: 9)) -> ContiguousArray<MACDIndicatorValue?>? {
        indicatorSeriesStore.macdSeries[key]
    }
    
    /// 读取 MACD 指标可见区间序列。
    func visibleMacdValues(for key: Indicator.Key = .macd(shortPeriod: 12, longPeriod: 26, signalPeriod: 9)) -> ArraySlice<MACDIndicatorValue?>? {
        visibleValues(from: macdValues(for: key))
    }
}
