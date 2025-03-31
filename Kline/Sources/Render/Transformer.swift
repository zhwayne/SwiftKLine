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
    
    func merge(_ other: AxisInset) -> AxisInset {
        AxisInset(top: top + other.top, bottom: bottom + other.bottom)
    }
}

@MainActor
struct Transformer {

    var contentInset: AxisInset
    var dataBounds: MetricBounds
    let viewPort: CGRect
    let itemCount: Int
    let visibleRange: Range<Int>
    let indices: Range<Int>
    
    private var itemWidth: CGFloat { width + gap }
    private var width: CGFloat { StyleManager.shared.candleStyle.width }
    private var gap: CGFloat { StyleManager.shared.candleStyle.gap }
    
    init(
        contentInset: AxisInset = .zero,
        dataBounds: MetricBounds,
        viewPort: CGRect,
        itemCount: Int,
        visibleRange: Range<Int>,
        indices: Range<Int>
    ) {
        self.contentInset = contentInset
        self.dataBounds = dataBounds
        self.viewPort = viewPort
        self.itemCount = itemCount
        self.visibleRange = visibleRange
        self.indices = indices
    }
    
    /// 将数据索引映射为图表上的 x 坐标。
    func xAxis(at index: Int) -> CGFloat {
        return CGFloat(index) * itemWidth
    }
    
    func xAxisInLayer(at index: Int) -> CGFloat {
        xAxis(at: index) + viewPort.minX
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
    func yAxis(for value: Double, inset: AxisInset) -> CGFloat {
        // 将数据值映射到图表高度上的位置。
        // valueRatio 表示数据值在最小值和最大值之间的归一化比例。
        let valueRatio = CGFloat((value - dataBounds.min) / dataBounds.distance)
        let adjustedInset = contentInset.merge(inset)
        let height = viewPort.height - adjustedInset.top - adjustedInset.bottom
        return adjustedInset.top + (1.0 - valueRatio) * height
    }
    
    func yAxis(for value: Double) -> CGFloat {
        return yAxis(for: value, inset: .zero)
    }
    
    func valueOf(yAxis y: CGFloat) -> Double {
        let topY = contentInset.top
        let bottomY = viewPort.height - contentInset.bottom
        let valueRatio = CGFloat((y - topY) / (bottomY - topY))
        return dataBounds.min + (1 - valueRatio) * dataBounds.distance
    }
}
