//
//  Diff.swift
//  SwiftKLine
//
//  Created by W Zh on 2025/7/28.
//

import Foundation

struct DiffResult<T> {
    var inserted: [(index: Int, renderer: T)] = []
    var deleted: [(index: Int, renderer: T)] = []
    var moved: [(from: Int, to: Int, renderer: T)] = []
    var unchanged: [(index: Int, renderer: T)] = []
}

func diff<T: Hashable & Equatable>(
    old: [T],
    new: [T]
) -> DiffResult<T> {
    var result = DiffResult<T>()

    // 构建索引映射
    var oldIndices = [T: Int]()
    for (i, item) in old.enumerated() {
        oldIndices[item] = i
    }

    var seen = Set<T>()  // 用于后面识别删除项

    for (newIndex, renderer) in new.enumerated() {
        if let oldIndex = oldIndices[renderer] {
            seen.insert(renderer)
            if oldIndex == newIndex {
                result.unchanged.append((index: newIndex, renderer: renderer))
            } else {
                result.moved.append((from: oldIndex, to: newIndex, renderer: renderer))
            }
        } else {
            result.inserted.append((index: newIndex, renderer: renderer))
        }
    }

    for (oldIndex, renderer) in old.enumerated() {
        if !seen.contains(renderer) {
            result.deleted.append((index: oldIndex, renderer: renderer))
        }
    }

    return result
}
