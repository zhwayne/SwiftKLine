//
//  DataMerger.swift
//  SwiftKLine
//
//  Created by zhwayne on 2026/4/27.
//

import Foundation

struct DataMerger {
    private var bucketDuration: Int?

    mutating func reset() {
        bucketDuration = nil
    }

    mutating func merge(current: [any ChartItem], patch: [any ChartItem]) -> [any ChartItem] {
        let merged: [any ChartItem]
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

    mutating func prepareBucketsIfNeeded(with items: [any ChartItem]) {
        updateBucketDurationIfNeeded(with: items)
    }

    mutating func applyLiveTick(
        _ tick: any ChartItem,
        to items: inout [any ChartItem]
    ) -> LiveTickMergeResult {
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

    private mutating func updateBucketDurationIfNeeded(with items: [any ChartItem]) {
        guard bucketDuration == nil else { return }
        updateBucketDurationIfNeeded(with: items.map(\.timestamp))
    }

    private mutating func updateBucketDurationIfNeeded(
        with items: [any ChartItem],
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

    private func indexOfBucket(for timestamp: Int, in items: [any ChartItem]) -> Int? {
        let target = bucketStart(for: timestamp)
        return items.firstIndex { bucketStart(for: $0.timestamp) == target }
    }

    private func insertionIndexForBucket(_ timestamp: Int, in items: [any ChartItem]) -> Int {
        let target = bucketStart(for: timestamp)
        return items.firstIndex { bucketStart(for: $0.timestamp) > target } ?? items.endIndex
    }
}
