//
//  IndicatorValueCache.swift
//  SwiftKLine
//
//  Created by W Zh on 2025/12/1.
//

import Foundation

/// 描述数据变化类型，便于按需重算指标
enum IndicatorValueChange: Equatable {
    /// 数据集完全重置或无法增量重算
    case reset
    /// 在尾部追加了若干条数据
    case append(count: Int)
    /// 在头部追加了历史分页数据
    case prepend(count: Int)
    /// 更新了指定区间的数据（覆盖/补丁）
    case patch(range: Range<Int>)
    /// 没有实质变化
    case none
    
    func merged(with other: IndicatorValueChange) -> IndicatorValueChange {
        switch (self, other) {
        case (.reset, _), (_, .reset):
            return .reset
        case let (.prepend(a), .prepend(b)):
            return .prepend(count: a + b)
        case let (.append(a), .append(b)):
            return .append(count: a + b)
        case let (.patch(lhs), .patch(rhs)):
            let lower = Swift.min(lhs.lowerBound, rhs.lowerBound)
            let upper = Swift.max(lhs.upperBound, rhs.upperBound)
            return .patch(range: lower..<upper)
        case (.none, let change), (let change, .none):
            return change
        default:
            return .reset
        }
    }
}

/// 负责缓存指标计算结果，并在数据变化时只重算必要部分
actor IndicatorValueCache {
    
    private var storage = ValueStorage()
    private var cachedCounts: [Indicator.Key: Int] = [:]
    
    var valueStorage: ValueStorage { storage }
    
    func reset() {
        storage = ValueStorage()
        cachedCounts.removeAll()
    }
    
    func remove(keys: [Indicator.Key]) {
        keys.forEach { key in
            storage.remove(forKey: key)
            cachedCounts.removeValue(forKey: key)
        }
    }
    
    /// 计算并更新指定指标键的值
    /// - Parameters:
    ///   - keys: 需要重算的指标键
    ///   - items: 最新的数据序列
    ///   - change: 数据变化描述
    /// - Returns: 更新后的 ValueStorage
    func rebuild(
        keys: [Indicator.Key],
        items: [any KLineItem],
        change: IndicatorValueChange
    ) -> ValueStorage {
        let dedupedKeys = deduplicated(keys)
        if dedupedKeys.isEmpty {
            reset()
            return storage
        }
        for key in dedupedKeys {
            recalculate(for: key, items: items, change: change)
            cachedCounts[key] = items.count
        }
        return storage
    }
}

// MARK: - 计算路径
private extension IndicatorValueCache {
    
    func recalculate(
        for key: Indicator.Key,
        items: [any KLineItem],
        change: IndicatorValueChange
    ) {
        if let lookback = key.lookback {
            recalcWindowed(
                key: key,
                lookback: lookback,
                items: items,
                change: change
            )
        } else {
            recalcStateful(for: key, items: items)
        }
    }
    
    private func recalcStateful(
        for key: Indicator.Key,
        items: [any KLineItem]
    ) {
        let calculator = key.makeCalculator()
        let values = calculator.calculate(for: items)
        storage.set(value: values, forKey: key)
    }
    
    private func recalcWindowed<C: IndicatorCalculator>(
        key: Indicator.Key,
        lookback: Int,
        items: [any KLineItem],
        change: IndicatorValueChange,
        calculator: C
    ) where C.Result: Sendable {
        let newCount = items.count
        var result = storage.getValue(forKey: key, type: [C.Result?].self) ?? []
        result = resized(result, to: newCount)
        
        // 数据长度减少或无法识别变化，退化为全量重算
        guard newCount >= (cachedCounts[key] ?? 0),
              change != .reset else {
            let values = calculator.calculate(for: items)
            storage.set(value: values, forKey: key)
            return
        }
        
        switch change {
        case let .append(count):
            let contextStart = max(0, newCount - count - (lookback - 1))
            let recomputeRange = contextStart..<newCount
            write(valuesFrom: calculator, items: items, range: recomputeRange, into: &result)
            storage.set(value: result, forKey: key)
        case let .patch(range):
            let contextStart = max(0, range.lowerBound - (lookback - 1))
            let contextEnd = min(newCount, range.upperBound + lookback)
            let recomputeRange = contextStart..<contextEnd
            write(valuesFrom: calculator, items: items, range: recomputeRange, into: &result)
            storage.set(value: result, forKey: key)
        case let .prepend(count):
            // 前插影响“新前缀 + 过渡区”，其余区域尝试平移复用
            var shifted = Array<C.Result?>(repeating: nil, count: newCount)
            let reuseStart = min(newCount, count)
            let copyCount = max(0, result.count - reuseStart)
            if copyCount > 0 {
                let upperBound = Swift.min(shifted.count, reuseStart + copyCount)
                if reuseStart < upperBound, (reuseStart - count) >= 0 {
                    for idx in reuseStart..<upperBound {
                        let source = idx - count
                        if source < result.count {
                            shifted[idx] = result[source]
                        }
                    }
                }
            }
            let recomputeEnd = min(newCount, count + lookback)
            let recomputeRange = 0..<recomputeEnd
            write(valuesFrom: calculator, items: items, range: recomputeRange, into: &shifted)
            storage.set(value: shifted, forKey: key)
        case .none:
            // 不需要重算
            storage.set(value: result, forKey: key)
        case .reset:
            let values = calculator.calculate(for: items)
            storage.set(value: values, forKey: key)
        }
    }
    
    private func recalcWindowed(
        key: Indicator.Key,
        lookback: Int,
        items: [any KLineItem],
        change: IndicatorValueChange
    ) {
        switch key {
        case let .ma(period):
            recalcWindowed(
                key: key,
                lookback: lookback,
                items: items,
                change: change,
                calculator: MACalculator(period: period)
            )
        case let .wma(period):
            recalcWindowed(
                key: key,
                lookback: lookback,
                items: items,
                change: change,
                calculator: WMACalculator(period: period)
            )
        case .boll:
            recalcWindowed(
                key: key,
                lookback: lookback,
                items: items,
                change: change,
                calculator: BOLLCalculator()
            )
        case .vol:
            recalcWindowed(
                key: key,
                lookback: lookback,
                items: items,
                change: change,
                calculator: VOLCalculator()
            )
        default:
            let calculator = key.makeCalculator()
            let values = calculator.calculate(for: items)
            storage.set(value: values, forKey: key)
        }
    }
    
    private func write<C: IndicatorCalculator>(
        valuesFrom calculator: C,
        items: [any KLineItem],
        range: Range<Int>,
        into target: inout [C.Result?]
    ) where C.Result: Sendable {
        guard !range.isEmpty else { return }
        let contextStart = range.lowerBound
        let contextItems = Array(items[contextStart..<range.upperBound])
        let values = calculator.calculate(for: contextItems)
        for (offset, value) in values.enumerated() {
            let index = contextStart + offset
            if index < target.count {
                target[index] = value
            }
        }
    }
    
    private func resized<T>(_ values: [T?], to count: Int) -> [T?] {
        var buffer = values
        if buffer.count < count {
            buffer.append(contentsOf: Array(repeating: nil, count: count - buffer.count))
        } else if buffer.count > count {
            buffer.removeLast(buffer.count - count)
        }
        return buffer
    }
    
    private func deduplicated(_ keys: [Indicator.Key]) -> [Indicator.Key] {
        var seen = Set<Indicator.Key>()
        var result: [Indicator.Key] = []
        for key in keys where !seen.contains(key) {
            seen.insert(key)
            result.append(key)
        }
        return result
    }
}
