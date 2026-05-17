import UIKit

struct CandleDimensions: Equatable, Sendable {
    var width: CGFloat
    var gap: CGFloat

    init(width: CGFloat = 10, gap: CGFloat = 2) {
        self.width = width
        self.gap = gap
    }

    var itemWidth: CGFloat { width + gap }
}