import UIKit

@MainActor
public protocol AnimationDriver: AnyObject {
    var onStep: ((Double) -> Void)? { get set }
    var onCompleted: (() -> Void)? { get set }
    
    func start(duration: TimeInterval)
    func stop()
    func invalidate()
}

@MainActor
final class CADisplayLinkAnimationDriver: AnimationDriver {
    var onStep: ((Double) -> Void)?
    var onCompleted: (() -> Void)?
    
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var duration: TimeInterval = 0.25
    
    func start(duration: TimeInterval) {
        ensureDisplayLink()
        self.duration = max(duration, 1.0 / 60.0)
        startTime = CACurrentMediaTime()
        displayLink?.isPaused = false
        step()
    }
    
    func stop() {
        displayLink?.isPaused = true
    }
    
    func invalidate() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    private func ensureDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
        } else {
            link.preferredFramesPerSecond = 60
        }
        link.add(to: .main, forMode: .common)
        link.isPaused = true
        displayLink = link
    }
    
    @objc private func handleDisplayLink(_ link: CADisplayLink) {
        step()
    }
    
    private func step() {
        guard let displayLink else { return }
        let elapsed = CACurrentMediaTime() - startTime
        let progress = min(max(elapsed / duration, 0), 1)
        onStep?(progress)
        if progress >= 1 {
            displayLink.isPaused = true
            onCompleted?()
        }
    }
}

