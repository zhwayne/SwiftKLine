import UIKit

struct CandleScaleChange {
    let width: CGFloat
    let gap: CGFloat
}

class PinchInteraction: NSObject, UIInteraction {
    
    weak var view: UIView?
    
    private var pinchCenterX: CGFloat = 0
    private var oldScale: CGFloat = 1
    private var scrollView: ChartScrollView { layout.scrollView }
    private let layout: ChartLayout
    private let onScaleChange: (CandleScaleChange) -> Void
    
    init(layout: ChartLayout, onScaleChange: @escaping (CandleScaleChange) -> Void) {
        self.layout = layout
        self.onScaleChange = onScaleChange
    }

    func willMove(to view: UIView?) {

    }

    func didMove(to view: UIView?) {
        let pinch = UIPinchGestureRecognizer(
            target: self,
            action: #selector(Self.handlePinch(_:))
        )
        view?.addGestureRecognizer(pinch)
    }
    
    @objc private func handlePinch(_ pinch: UIPinchGestureRecognizer) {
        switch pinch.state {
        case .began:
            scrollView.isScrollEnabled = false
            guard pinch.numberOfTouches >= 2 else { return }
            let p1 = pinch.location(ofTouch: 0, in: scrollView.contentView)
            let p2 = pinch.location(ofTouch: 1, in: scrollView.contentView)
            pinchCenterX = (p1.x + p2.x) / 2
            oldScale = 1.0
        case .changed:
            break
            
        default:
            scrollView.isScrollEnabled = true
            return
        }
        
        let difValue = pinch.scale - oldScale
        let dims = layout.candleDimensions
        let newLineWidth = dims.width * (difValue + 1)
        let newGap = dims.gap * (difValue + 1)
        guard (2...24).contains(newLineWidth) else { return }
        
        oldScale = pinch.scale
        let contentOffsetAtPinch = scrollView.contentOffset.x + pinchCenterX
        let oldContentSize = scrollView.contentSize
        
        onScaleChange(CandleScaleChange(width: newLineWidth, gap: newGap))
        
        let newContentSize = layout.contentSize
        guard oldContentSize.width > 0 else {
            scrollView.delegate?.scrollViewDidScroll?(scrollView)
            return
        }
        
        scrollView.contentSize = newContentSize
        
        let scale = newContentSize.width / oldContentSize.width
        let newContentOffsetAtPinch = contentOffsetAtPinch * scale
        var newContentOffsetX = newContentOffsetAtPinch - pinchCenterX
        
        newContentOffsetX = max(-scrollView.contentInset.left, newContentOffsetX)
        let maxContentOffsetX = scrollView.contentSize.width - scrollView.bounds.width + scrollView.contentInset.right
        newContentOffsetX = min(maxContentOffsetX, newContentOffsetX)

        if scrollView.contentOffset.x == newContentOffsetX {
            scrollView.delegate?.scrollViewDidScroll?(scrollView)
        } else {
            scrollView.contentOffset.x = newContentOffsetX
        }
    }
}