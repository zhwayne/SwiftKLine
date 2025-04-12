//
//  Transformer.swift
//  KLineDemo
//
//  Created by iya on 2024/11/6.
//

import UIKit
import CoreLocation

struct AxisInset {
    let top: CGFloat
    let bottom: CGFloat
    
    static let zero = AxisInset(top: 0, bottom: 0)
    
    func merging(_ other: AxisInset) -> AxisInset {
        AxisInset(top: top + other.top, bottom: bottom + other.bottom)
    }
}

struct Transformer {
    
    enum CoordinatorSpace {
        case viewPort, layer
    }

    let axisInset: AxisInset
    var dataBounds: MetricBounds
    let viewPort: CGRect
    private let itemCount: Int
    private let visibleRange: Range<Int>
    private let indices: Range<Int>
    
    private var itemWidth: CGFloat { width + gap }
    private var width: CGFloat { StyleManager.shared.candleStyle.width }
    private var gap: CGFloat { StyleManager.shared.candleStyle.gap }
    
    init(
        axisInset: AxisInset = .zero,
        dataBounds: MetricBounds,
        viewPort: CGRect,
        itemCount: Int,
        visibleRange: Range<Int>,
        indices: Range<Int>
    ) {
        self.axisInset = axisInset
        self.dataBounds = dataBounds
        self.viewPort = viewPort
        self.itemCount = itemCount
        self.visibleRange = visibleRange
        self.indices = indices
    }
    
    /// 将数据索引映射为图表上的 x 坐标。
    func xAxis(at index: Int, space: CoordinatorSpace = .viewPort) -> CGFloat {
        if space == .viewPort {
            return CGFloat(index) * itemWidth
        } else {
            return CGFloat(index) * itemWidth + viewPort.minX
        }
    }
    
    func indexOfVisibleItem(xAxis x: CGFloat, extend: Bool = false) -> Int? {
        var index = Int(floor((x - viewPort.minX) / itemWidth))
        if viewPort.minX <= 0 {
            index += indices.lowerBound
        }
        if extend {
            return index
        }
        if visibleRange.contains(index) {
            return index
        }
        return nil
    }
    
    /// 将数据值映射为图表上的 y 坐标。
    func yAxis(for value: Double, inset: AxisInset = .zero) -> CGFloat {
        // 将数据值映射到图表高度上的位置。
        // valueRatio 表示数据值在最小值和最大值之间的归一化比例。
        let valueRatio = CGFloat((value - dataBounds.min) / dataBounds.distance)
        let adjustedInset = self.axisInset.merging(inset)
        let height = viewPort.height - adjustedInset.top - adjustedInset.bottom
        return adjustedInset.top + (1.0 - valueRatio) * height
    }
    
    func valueOf(yAxis y: CGFloat) -> Double {
        let topY = axisInset.top
        let bottomY = viewPort.height - axisInset.bottom
        let valueRatio = CGFloat((y - topY) / (bottomY - topY))
        return dataBounds.min + (1 - valueRatio) * dataBounds.distance
    }
}
