//
//  Array++.swift
//  KLineDemo
//
//  Created by iya on 2024/11/1.
//

import Foundation

extension Array where Element == KLineItem {
    /// 使用提供的计算器数组计算指标，并将结果装饰到数据中。
    ///
    /// - Parameter calculators: 用于计算指标的 `IndicatorCalculator` 数组。
    /// - Returns: 包含原始 `KLineItem` 和关联指标的 `IndicatorData` 数组。
    func decorateWithIndicators(calculators: [any IndicatorCalculator]) async -> [IndicatorData] {
        let decoratedItemsActor = DecoratedItemsActor(items: self.map { IndicatorData(item: $0) })
        
        await withTaskGroup(of: Void.self) { group in
            for calculator in calculators {
                group.addTask {
                    let values = calculator.calculate(for: self)
                    await decoratedItemsActor.update(key: calculator.key, values: values)
                }
            }
            await group.waitForAll()
        }
        
        return await decoratedItemsActor.items
    }
}

private actor DecoratedItemsActor {
    var items: [IndicatorData]
    
    init(items: [IndicatorData]) {
        self.items = items
    }
    
    func update(key: IndicatorKey, values: [IndicatorValue?]) {
        
        for i in 0..<items.count {
            if let value = values[i] {
                items[i].setIndicator(value: value, forKey: key)
            }
        }
    }
}

extension Collection where Element == IndicatorData {
    /// 计算特定数值型指标的范围（最大值和最小值）。
    ///
    /// - Parameter key: 要计算范围的 `IndicatorKey`。
    /// - Returns: 包含最大值和最小值的 `MetricBounds`，若无有效数据则返回 `nil`。
    func bounds(for key: IndicatorKey) -> MetricBounds? {
        // 提取特定指标的所有非 nil 值，并尝试转换为 Double
        let indicatorValues: [Double] = self.compactMap { data in
            if let value = data.indicator(forKey: key) {
                return value.doubeValue
            }
            return nil
        }
        
        // 如果没有有效的数据，返回 nil
        guard !indicatorValues.isEmpty,
              let minVal = indicatorValues.min(),
              let maxVal = indicatorValues.max() else {
            return nil
        }
        
        return MetricBounds(max: maxVal, min: minVal)
    }
}


extension Collection where Element == KLineItem {
    
    /// 计算数组中的价格范围（最大值和最小值）。
    var priceBounds: MetricBounds {
        guard !isEmpty else { return .zero }

        let minPrice = self.map { Swift.min($0.opening, $0.closing, $0.highest, $0.lowest) }.min() ?? 0
        let maxPrice = self.map { Swift.max($0.opening, $0.closing, $0.highest, $0.lowest) }.max() ?? 0
        
        return MetricBounds(max: maxPrice, min: minPrice)
    }
}
