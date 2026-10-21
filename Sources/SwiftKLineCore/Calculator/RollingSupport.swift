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
