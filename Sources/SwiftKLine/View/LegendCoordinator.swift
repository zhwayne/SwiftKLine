//
//  LegendCoordinator.swift
//  SwiftKLine
//
//  Created by zhwayne on 2026/4/27.
//

import UIKit

@MainActor
struct LegendCoordinator {
    func configureLegend<Key: Hashable>(
        for group: RendererGroup,
        groupFrame: CGRect,
        legendKey: Key,
        legendLabel: UILabel,
        legendCache: inout LegendCache<Key>,
        context: RendererContext
    ) -> (viewPortOffsetY: CGFloat, cost: CFTimeInterval) {
        let legendStart = CACurrentMediaTime()
        let cachedLegend = legendCache[legendKey]
        let legendText = cachedLegend?.text ?? LegendCache<Key>.makeLegendText(
            for: group.renderers,
            context: context
        )
        let legendCost = CACurrentMediaTime() - legendStart
        guard !legendText.string.isEmpty else {
            if group.chartSection == .mainChart {
                legendLabel.attributedText = nil
                legendCache.resetLastMainKey()
            }
            context.legendText = nil
            context.legendFrame = .zero
            return (0, legendCost)
        }

        context.legendText = legendText
        if group.chartSection == .mainChart {
            if legendCache.lastMainKey != legendKey {
                legendLabel.attributedText = legendText
                if let cachedLegend {
                    legendLabel.frame.size = cachedLegend.size
                } else {
                    legendLabel.sizeToFit()
                }
                legendCache.markMainKey(legendKey)
            }
            let legendFrame = CGRect(origin: legendLabel.frame.origin, size: legendLabel.frame.size)
            context.legendFrame = legendFrame
            if legendCache[legendKey] == nil {
                legendCache.store(.init(text: legendText, size: legendFrame.size), for: legendKey)
            }
            return (legendFrame.maxY, legendCost)
        }

        let measuredSize: CGSize
        if let cachedLegend {
            measuredSize = cachedLegend.size
        } else {
            let boundingRect = legendText.boundingRect(
                with: CGSize(width: groupFrame.width * 0.8, height: groupFrame.height),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            measuredSize = boundingRect.size
            legendCache.store(.init(text: legendText, size: measuredSize), for: legendKey)
        }
        context.legendFrame = CGRect(
            x: 12, y: groupFrame.minY + group.padding.top,
            width: measuredSize.width, height: measuredSize.height
        )
        return (measuredSize.height + group.legendSpacing, legendCost)
    }
}
