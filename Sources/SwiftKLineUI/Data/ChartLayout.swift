//
//  ChartLayout.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2025/04/19.
//

import SwiftKLineCore
import UIKit

/// Maps chronological candle positions and current group values into viewport coordinates.
///
/// The same layout object is reused across chart groups. Its dataBounds describe the group currently being drawn,
/// not a global range across every indicator.
@MainActor public final class ChartLayout {
    let scrollView: ChartScrollView
    
    var itemCount: Int = 0 {
        didSet { updateContentSize() }
    }
    
    /// The current group’s visible value bounds, assigned by the drawing coordinator.
    public internal(set)
    var dataBounds: ValueBounds = .empty
    
    var candleDimensions: CandleDimensions
        
    init(scrollView: ChartScrollView, candleDimensions: CandleDimensions) {
        self.scrollView = scrollView
        self.candleDimensions = candleDimensions
    }
    
    func updateContentSize() {
        scrollView.contentSize = contentSize
    }
        
    @inline(__always)
    var contentSize: CGSize {
        let dims = candleDimensions
        let width = max(CGFloat(itemCount) * dims.itemWidth - dims.gap, scrollView.bounds.width)
        return CGSize(width: width, height: 0)
    }
    
    @inline(__always)
    var indices: Range<Int> {
        let dims = candleDimensions
        let contentOffset = scrollView.contentOffset
        let itemWidth = dims.itemWidth
        guard itemWidth > 0 else { return 0..<0 }
        let startIndex = Int(floor(contentOffset.x / itemWidth))
        let offset = CGFloat(startIndex) * itemWidth - contentOffset.x
        let width = scrollView.frame.width + abs(min(0, offset))
        let itemCountToBeDrawn = Int(ceil(width / itemWidth))
        guard startIndex < itemCount else { return 0..<0 }
        return startIndex..<(startIndex + itemCountToBeDrawn)
    }
    
    /// The visible absolute candle range clamped to zero through itemCount.
    @inline(__always)
    var visibleRange: Range<Int> {
        let range = indices
        let lowerBound = min(max(range.lowerBound, 0), itemCount)
        let upperBound = max(min(range.upperBound, itemCount), 0)
        return lowerBound..<upperBound
    }
    
    @inline(__always)
    var frameOfVisibleRange: CGRect {
        guard !visibleRange.isEmpty else { return .zero }
        let dims = candleDimensions
        let contentOffset = scrollView.contentOffset
        let lowerBound = CGFloat(visibleRange.lowerBound)
        let upperBound = CGFloat(visibleRange.upperBound)
        let offset = lowerBound * dims.itemWidth - contentOffset.x
        let width = (upperBound - lowerBound) * dims.itemWidth
        let height = scrollView.frame.height
        return CGRect(x: offset, y: 0, width: width, height: height)
    }
}

extension ChartLayout {

    /// Maps a visible-relative candle index to the left edge of its candle body.
    ///
    /// - Parameter index: Offset relative to visibleRange.lowerBound, not an absolute input-array index.
    /// - Returns: Horizontal position in viewport-canvas coordinates; add half the candle width for its center.
    @inline(__always)
    public func xPosition(at index: Int) -> CGFloat {
        let dims = candleDimensions
        return CGFloat(index) * dims.itemWidth + frameOfVisibleRange.minX
    }
    
    /// Maps x to an absolute candle index without clamping; callers may use the result outside visibleRange.
    @inline(__always)
    func unsafeIndexInViewport(on x: CGFloat) -> Int {
        let dims = candleDimensions
        let itemWidth = dims.itemWidth
        guard itemWidth > 0 else { return 0 }
        let viewPort = frameOfVisibleRange
        var index = Int(floor((x - viewPort.minX) / itemWidth))
        if viewPort.minX <= 0 {
            index += indices.lowerBound
        }
        return index
    }
    
    /// Maps x to an absolute candle index only when it belongs to the current visible range.
    @inline(__always)
    func indexInViewport(on x: CGFloat) -> Int? {
        let index = unsafeIndexInViewport(on: x)
        if visibleRange.contains(index) {
            return index
        }
        return nil
    }
}

extension ChartLayout {
    
    /// Maps a data value to the current section’s drawable rectangle.
    ///
    /// - Parameters:
    ///   - value: The price or indicator value to position.
    ///   - viewPort: The drawable section rectangle in viewport-canvas coordinates.
    /// - Returns: A y coordinate, or the viewport midpoint when the range or value is not drawable.
    @inline(__always)
    public func yPosition(for value: Double, viewPort: CGRect) -> CGFloat {
        let value = CGFloat(value)
        guard value.isFinite, dataBounds.distance.isFinite, dataBounds.distance > 0 else { return viewPort.midY }
        // Normalize the value within the current group range.
        let ratio = (value - dataBounds.min) / dataBounds.distance
        let height = viewPort.height
        let y = (1 - ratio) * height + viewPort.minY
        return y
    }
    
    /// Maps a viewport y coordinate back to a group value; flat or unavailable ranges return the current lower bound.
    @inline(__always)
    public func value(on y: CGFloat, viewPort: CGRect) -> Double {
        guard viewPort.height > 0, dataBounds.distance.isFinite, dataBounds.distance > 0 else {
            return dataBounds.min
        }
        let minY = viewPort.minY
        let ratio = Double((y - minY) / viewPort.height)
        let value = dataBounds.min + (1 - ratio) * dataBounds.distance
        return value
    }
}

extension ChartLayout {
    
    /// Generates finite, advancing grid steps and stops if floating-point precision prevents further progress.
    func gridValues(in viewPort: CGRect, groupFrame: CGRect) -> [(value: Double, y: CGFloat)] {
        let (stepSize, _) = determineNiceGridSteps(maxLines: 7)
        guard stepSize.isFinite, stepSize > 0 else { return [] }
        var gridValues = [(Double, CGFloat)]()
        var value = floor(dataBounds.min / stepSize) * stepSize
        var y = yPosition(for: value, viewPort: viewPort)
        while y > groupFrame.minY, gridValues.count < 16 {
            if y < groupFrame.maxY {
                gridValues.append((value, y))
            }
            let next = value + stepSize
            guard next > value else { break } // A step smaller than the price ULP cannot advance.
            value = next
            y = self.yPosition(for: value, viewPort: viewPort)
        }
        return gridValues
    }
    
    /// Chooses a readable finite step size for the current value range, returning zero when no safe step exists.
    private func determineNiceGridSteps(maxLines: Int) -> (step: Double, count: Int) {
        let range = dataBounds.distance
        guard range.isFinite, range > 0, maxLines > 0 else { return (0, 0) }
        
        // Estimate a readable grid step.
        let roughStep = range / Double(maxLines)
        
        // Find the decimal order of magnitude.
        let magnitude = pow(10, floor(log10(roughStep)))
        guard magnitude.isFinite, magnitude > 0 else { return (0, 0) }
        let normalizedStep = roughStep / magnitude
        
        // Select the nearest readable step at that magnitude.
        let niceSteps: [Double] = [0.1, 0.2, 0.25, 0.5, 1.0, 2.0, 2.5, 5.0, 10.0]
        let chosenStep = niceSteps.first { $0 >= normalizedStep } ?? normalizedStep
        
        let actualStep = chosenStep * magnitude
        guard actualStep.isFinite, actualStep > 0 else { return (0, 0) }
        let stepCount = Int(min(Double(maxLines), ceil(range / actualStep)))
        
        return (actualStep, Swift.min(stepCount, maxLines))
    }
}
