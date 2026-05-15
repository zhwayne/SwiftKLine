import Foundation

public protocol KLineValueBounds {
    var min: Double { get }
    var max: Double { get }
}

extension KLineIndicatorCalculator {
    func eraseToAnyIndicatorCalculator() -> AnyIndicatorCalculator {
        AnyIndicatorCalculator(self)
    }
}
