//
//  LiveTickMergeResult.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2026/05/17.
//

import Foundation

/// Describes the earliest changed candle index so rendering can invalidate only the affected suffix.
package enum LiveTickMergeResult: Equatable {
    /// A new candle was inserted; appendedToTail distinguishes history insertion from a new latest candle.
    case inserted(index: Int, appendedToTail: Bool)
    /// An existing candle identity was revised without shifting later indexes.
    case replaced(index: Int)
}