import Foundation

extension IndicatorCalculator {
    func eraseToAnyIndicatorCalculator() -> AnyIndicatorCalculator {
        AnyIndicatorCalculator(self)
    }
}
