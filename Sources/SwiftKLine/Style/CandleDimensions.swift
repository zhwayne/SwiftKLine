import UIKit

public struct CandleDimensions: Equatable, Sendable {
    public var width: CGFloat
    public var gap: CGFloat

    public init(width: CGFloat = 10, gap: CGFloat = 2) {
        self.width = width
        self.gap = gap
    }

    public var itemWidth: CGFloat { width + gap }
}