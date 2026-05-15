import Foundation

extension KLineIndicatorCalculator {
    func eraseToAnyIndicatorCalculator() -> AnyIndicatorCalculator {
        AnyIndicatorCalculator(self)
    }
}
