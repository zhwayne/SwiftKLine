//
//  RollingSupport.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2026/10/21.
//

import Foundation

/// Resizes output storage while preserving a reusable prefix.
///
/// An index outside the old output or new input forces recalculation from zero.
/// - Returns: The safe starting index; callers remain responsible for the prefix’s semantic validity.
func prepareValues<Value>(_ values: inout [Value?], count: Int, from index: Int) -> Int {
    let start = index >= 0 && index <= min(values.count, count) ? index : 0
    if values.count > count { values.removeLast(values.count - count) }
    if values.count < count { values.append(contentsOf: repeatElement(nil, count: count - values.count)) }
    return start
}

/// A small array-backed deque with amortized constant-time removal from either end.
///
/// Removed front elements are retained behind a moving head index and compacted geometrically. This keeps the
/// rolling-indicator hot path free of `Array.removeFirst()` shifts while avoiding unbounded retained storage.
struct RollingDeque<Element> {
    private var storage: [Element] = []
    private var head = 0

    var first: Element? {
        head < storage.count ? storage[head] : nil
    }

    var last: Element? {
        head < storage.count ? storage.last : nil
    }

    mutating func reserveCapacity(_ minimumCapacity: Int) {
        storage.reserveCapacity(minimumCapacity)
    }

    mutating func append(_ element: Element) {
        storage.append(element)
    }

    @discardableResult
    mutating func removeFirst() -> Element? {
        guard head < storage.count else { return nil }
        let element = storage[head]
        head += 1
        compactIfNeeded()
        return element
    }

    @discardableResult
    mutating func removeLast() -> Element? {
        guard head < storage.count else { return nil }
        let element = storage.removeLast()
        if head == storage.count {
            storage.removeAll(keepingCapacity: true)
            head = 0
        }
        return element
    }

    private mutating func compactIfNeeded() {
        if head == storage.count {
            storage.removeAll(keepingCapacity: true)
            head = 0
        } else if head >= 1_024, head >= storage.count / 2 {
            storage.removeFirst(head)
            head = 0
        }
    }
}
