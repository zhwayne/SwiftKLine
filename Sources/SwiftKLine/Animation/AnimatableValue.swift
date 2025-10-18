import Foundation

public protocol AnimatableValue {
    static func interpolate(from: Self, to: Self, progress: Double) -> Self
}

