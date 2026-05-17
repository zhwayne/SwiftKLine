import UIKit

public struct CandleStyle: Equatable {
    public let risingColor: UIColor
    public let fallingColor: UIColor
    public let width: CGFloat
    public let gap: CGFloat

    public init(
        risingColor: UIColor = .systemTeal,
        fallingColor: UIColor = .systemPink,
        width: CGFloat = 10,
        gap: CGFloat = 2
    ) {
        self.risingColor = risingColor
        self.fallingColor = fallingColor
        self.width = width
        self.gap = gap
    }
}