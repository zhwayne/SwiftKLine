//
//  ChartLayout.swift
//  SwiftKLine
//
//  Created by iya on 2025/4/19.
//

import UIKit

/// 负责处理K线图布局相关的计算
@MainActor public final class ChartLayout {
    let scrollView: ChartScrollView
    
    var itemCount: Int = 0 {
        didSet { updateContentSize() }
    }
    
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
    public var contentSize: CGSize {
        let dims = candleDimensions
        let width = max(CGFloat(itemCount) * dims.itemWidth - dims.gap, scrollView.bounds.width)
        return CGSize(width: width, height: 0)
    }
    
    @inline(__always)
    public var indices: Range<Int> {
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
    
    /// 获取实际可见的K线索引范围
    /// 确保索引范围在有效范围内（0到itemCount之间）
    @inline(__always)
    public var visibleRange: Range<Int> {
        let range = indices
        let lowerBound = min(max(range.lowerBound, 0), itemCount)
        let upperBound = max(min(range.upperBound, itemCount), 0)
        return lowerBound..<upperBound
    }
    
    @inline(__always)
    public var frameOfVisibleRange: CGRect {
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
//    public enum CoordinateSpace {
//        case global, local
//    }
    
    @inline(__always)
    public func xPosition(at index: Int) -> CGFloat {
        let dims = candleDimensions
        return CGFloat(index) * dims.itemWidth + frameOfVisibleRange.minX
    }
    
    /// 根据x坐标计算对应的相对数据索引
    /// - Parameter x: x轴坐标
    /// - Returns: 相对数据索引，请注意该值可能会超过可见数据范围。
    @inline(__always)
    public func unsafeIndexInViewport(on x: CGFloat) -> Int {
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
    
    @inline(__always)
    public func indexInViewport(on x: CGFloat) -> Int? {
        let index = unsafeIndexInViewport(on: x)
        if visibleRange.contains(index) {
            return index
        }
        return nil
    }
}

extension ChartLayout {
    
    /// // 将数据值映射到图表高度上的位置。
    /// - Parameters:
    ///   - value: 当前数据值
    ///   - drawRect: 绘制区域
    /// - Returns: 映射后的 y 坐标。
    @inline(__always)
    public func yPosition(for value: Double, viewPort: CGRect) -> CGFloat {
        let value = CGFloat(value)
        guard dataBounds.distance > 0 else { return 0 }
        // 表示数据值在最小值和最大值之间的归一化比例。
        let ratio = (value - dataBounds.min) / dataBounds.distance
        let height = viewPort.height
        let y = (1 - ratio) * height + viewPort.minY
        return y
    }
    
    @inline(__always)
    public func value(on y: CGFloat, viewPort: CGRect) -> Double {
        guard viewPort.height > 0, dataBounds.distance > 0 else {
            return dataBounds.min
        }
        let minY = viewPort.minY
        let ratio = Double((y - minY) / viewPort.height)
        let value = dataBounds.min + (1 - ratio) * dataBounds.distance
        return value
    }
}

extension ChartLayout {
    
    func gridValues(in viewPort: CGRect, groupFrame: CGRect) -> [(value: Double, y: CGFloat)] {
        let (stepSize, _) = determineNiceGridSteps(maxLines: 7)
        guard stepSize > 0 else { return [(0, 0)] }
        var gridValues = [(Double, CGFloat)]()
        var value = floor(dataBounds.min / stepSize) * stepSize
        var y = yPosition(for: value, viewPort: viewPort)
        while y > groupFrame.minY {
            if y < groupFrame.maxY {
                gridValues.append((value, y))
            }
            value += stepSize
            y = self.yPosition(for: value, viewPort: viewPort)
        }
        return gridValues
    }
    
    private func determineNiceGridSteps(maxLines: Int) -> (step: Double, count: Int) {
        let range = dataBounds.distance
        guard range > 0, maxLines > 0 else { return (0, 0) }
        
        // 计算初始估算步长
        let roughStep = range / Double(maxLines)
        
        // 计算数量级
        let magnitude = pow(10, floor(log10(roughStep)))
        let normalizedStep = roughStep / magnitude
        
        // 选择最接近的标准步长
        let niceSteps: [Double] = [0.1, 0.2, 0.25, 0.5, 1.0, 2.0, 2.5, 5.0, 10.0]
        let chosenStep = niceSteps.first { $0 >= normalizedStep } ?? normalizedStep
        
        let actualStep = chosenStep * magnitude
        let stepCount = Int(ceil(range / actualStep))
        
        return (actualStep, Swift.min(stepCount, maxLines))
    }
}
