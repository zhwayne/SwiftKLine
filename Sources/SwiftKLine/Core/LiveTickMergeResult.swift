import Foundation

enum LiveTickMergeResult: Equatable {
    case inserted(index: Int, appendedToTail: Bool)
    case replaced(index: Int)
}