import UIKit

@MainActor
public final class Animator<Value: AnimatableValue> {
    public typealias FrameHandler = (Value, Double) -> Void
    public typealias CompletionHandler = (Value) -> Void
    
    public var onFrame: FrameHandler?
    public var onCompletion: CompletionHandler?
    
    private var driver: AnimationDriver
    private var startValue: Value?
    private var targetValue: Value?
    private var lastOutput: Value?
    
    public init(driver: AnimationDriver? = nil) {
        self.driver = driver ?? CADisplayLinkAnimationDriver()
        self.driver.onStep = { [weak self] progress in
            self?.handleStep(progress: progress)
        }
        self.driver.onCompleted = { [weak self] in
            self?.finish()
        }
    }
    
    public func animate(from: Value, to: Value, duration: TimeInterval) {
        startValue = lastOutput ?? from
        targetValue = to
        driver.start(duration: duration)
        handleStep(progress: 0)
    }
    
    public func cancel() {
        driver.stop()
        startValue = nil
        targetValue = nil
        lastOutput = nil
    }
    
    deinit {
        MainActor.assumeIsolated {
            driver.invalidate()
        }
    }
    
    private func handleStep(progress: Double) {
        guard let startValue, let targetValue else { return }
        let value = Value.interpolate(from: startValue, to: targetValue, progress: progress)
        lastOutput = value
        onFrame?(value, progress)
    }
    
    private func finish() {
        guard let targetValue else { return }
        lastOutput = targetValue
        onCompletion?(targetValue)
        startValue = nil
        self.targetValue = nil
        lastOutput = nil
    }
}

