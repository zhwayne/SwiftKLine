//
//  KLineDataMerger.swift
//  SwiftKLine
//
//  Created by zhwayne on 2026/4/27.
//

import Foundation

enum KLineLiveTickMergeResult: Equatable {
    case inserted(index: Int, appendedToTail: Bool)
    case replaced(index: Int)
}

struct KLineDataMerger {
    private var bucketDuration: Int?

    mutating func reset() {
        bucketDuration = nil
    }

    mutating func merge(current: [any KLineItem], patch: [any KLineItem]) -> [any KLineItem] {
        let merged: [any KLineItem]
        if current.isEmpty {
            merged = patch.sorted { $0.timestamp < $1.timestamp }
        } else {
            var map = Dictionary(uniqueKeysWithValues: current.map { ($0.timestamp, $0) })
            for item in patch {
                map[item.timestamp] = item
            }
            merged = map.values.sorted { $0.timestamp < $1.timestamp }
        }
        updateBucketDurationIfNeeded(with: merged)
        return merged
    }

    mutating func prepareBucketsIfNeeded(with items: [any KLineItem]) {
        updateBucketDurationIfNeeded(with: items)
    }

    mutating func applyLiveTick(
        _ tick: any KLineItem,
        to items: inout [any KLineItem]
    ) -> KLineLiveTickMergeResult {
        if bucketDuration == nil {
            updateBucketDurationIfNeeded(with: items, additionalTimestamp: tick.timestamp)
        }

        guard !items.isEmpty else {
            items = [tick]
            return .inserted(index: 0, appendedToTail: true)
        }

        if let existingIndex = indexOfBucket(for: tick.timestamp, in: items) {
            items[existingIndex] = tick
            return .replaced(index: existingIndex)
        }

        let insertIndex = insertionIndexForBucket(tick.timestamp, in: items)
        let appendedToTail = insertIndex == items.endIndex
        items.insert(tick, at: insertIndex)
        return .inserted(index: insertIndex, appendedToTail: appendedToTail)
    }

    private mutating func updateBucketDurationIfNeeded(with items: [any KLineItem]) {
        guard bucketDuration == nil else { return }
        updateBucketDurationIfNeeded(with: items.map(\.timestamp))
    }

    private mutating func updateBucketDurationIfNeeded(
        with items: [any KLineItem],
        additionalTimestamp: Int
    ) {
        guard bucketDuration == nil else { return }
        updateBucketDurationIfNeeded(with: items.map(\.timestamp) + [additionalTimestamp])
    }

    private mutating func updateBucketDurationIfNeeded(with timestamps: [Int]) {
        let timestamps = timestamps.sorted()
        guard timestamps.count >= 2 else { return }
        var minDiff: Int?
        for index in 1..<timestamps.count {
            let diff = timestamps[index] - timestamps[index - 1]
            guard diff > 0 else { continue }
            minDiff = min(minDiff ?? diff, diff)
        }
        bucketDuration = minDiff
    }

    private func bucketStart(for timestamp: Int) -> Int {
        guard let bucketDuration, bucketDuration > 0 else { return timestamp }
        return (timestamp / bucketDuration) * bucketDuration
    }

    private func indexOfBucket(for timestamp: Int, in items: [any KLineItem]) -> Int? {
        let target = bucketStart(for: timestamp)
        return items.firstIndex { bucketStart(for: $0.timestamp) == target }
    }

    private func insertionIndexForBucket(_ timestamp: Int, in items: [any KLineItem]) -> Int {
        let target = bucketStart(for: timestamp)
        return items.firstIndex { bucketStart(for: $0.timestamp) > target } ?? items.endIndex
    }
}
