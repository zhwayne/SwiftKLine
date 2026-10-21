//
//  DataMerger.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2026/04/27.
//

import Foundation

/// Normalizes historical batches and applies live candle revisions.
///
/// The live-update path requires sorted, unique input produced by merge or previous live updates.
/// Period configuration is explicit; a gap between timestamps never changes candle identity.
package struct DataMerger {
    private var period: ChartPeriod?

    /// Creates a merger using exact timestamps unless a positive fixed period is supplied.
    package init(period: ChartPeriod? = nil) {
        self.period = period
    }

    /// Replaces bucket configuration when starting a new data source or manual data set.
    package mutating func reset(period: ChartPeriod? = nil) {
        self.period = period
    }

    /// Normalizes both batches and merges them in timestamp-bucket order.
    ///
    /// The last occurrence wins within each batch, and patch entries override matching current entries.
    /// Already ordered inputs take O(n + m) work; unordered batches incur an additional sort.
    package mutating func merge(current: [any ChartItem], patch: [any ChartItem]) -> [any ChartItem] {
        let left = normalized(current)
        let right = normalized(patch)
        var result: [any ChartItem] = []
        result.reserveCapacity(left.count + right.count)
        var i = 0
        var j = 0
        while i < left.count, j < right.count {
            let lhs = bucket(left[i].timestamp)
            let rhs = bucket(right[j].timestamp)
            if lhs < rhs {
                result.append(left[i]); i += 1
            } else if lhs > rhs {
                result.append(right[j]); j += 1
            } else {
                result.append(right[j]); i += 1; j += 1
            }
        }
        result.append(contentsOf: left[i...])
        result.append(contentsOf: right[j...])
        return result
    }

    /// Inserts or replaces one complete snapshot in an already normalized array.
    ///
    /// Tail replacement and append use O(1) comparisons; older ticks use O(log n) lookup.
    /// Insertion and copy-on-write may still move O(n) elements.
    /// - Returns: The earliest changed index and whether an insertion extended the tail.
    package mutating func applyLiveTick(_ tick: any ChartItem, to items: inout [any ChartItem]) -> LiveTickMergeResult {
        let target = bucket(tick.timestamp)
        if let last = items.last {
            let tail = bucket(last.timestamp)
            if target == tail {
                items[items.count - 1] = tick
                return .replaced(index: items.count - 1)
            }
            if target > tail {
                items.append(tick)
                return .inserted(index: items.count - 1, appendedToTail: true)
            }
        } else {
            items.append(tick)
            return .inserted(index: 0, appendedToTail: true)
        }
        var low = 0
        var high = items.count
        while low < high {
            let mid = low + (high - low) / 2
            if bucket(items[mid].timestamp) < target { low = mid + 1 } else { high = mid }
        }
        if low < items.count, bucket(items[low].timestamp) == target {
            items[low] = tick
            return .replaced(index: low)
        }
        items.insert(tick, at: low)
        return .inserted(index: low, appendedToTail: false)
    }

    /// Returns a bucket identity using floor division, avoiding multiplication overflow at integer limits.
    private func bucket(_ timestamp: Int) -> Int {
        guard let seconds = period?.seconds, seconds > 0 else { return timestamp }
        // Floor division supports dates before the Unix epoch without multiplying and overflowing.
        let quotient = timestamp / seconds
        return timestamp % seconds < 0 ? quotient - 1 : quotient
    }

    /// Sorts only when needed and retains the last input occurrence of each candle identity.
    private func normalized(_ items: [any ChartItem]) -> [any ChartItem] {
        guard items.count > 1 else { return items }
        let sorted = zip(items, items.dropFirst()).allSatisfy { bucket($0.timestamp) <= bucket($1.timestamp) }
        let ordered: [any ChartItem]
        if sorted {
            ordered = items
        } else {
            ordered = items.enumerated().sorted {
                let lhs = bucket($0.element.timestamp)
                let rhs = bucket($1.element.timestamp)
                return lhs == rhs ? $0.offset < $1.offset : lhs < rhs
            }.map(\.element)
        }
        var unique: [any ChartItem] = []
        unique.reserveCapacity(ordered.count)
        for item in ordered {
            if let last = unique.last, bucket(last.timestamp) == bucket(item.timestamp) {
                unique[unique.count - 1] = item
            } else {
                unique.append(item)
            }
        }
        return unique
    }
}
