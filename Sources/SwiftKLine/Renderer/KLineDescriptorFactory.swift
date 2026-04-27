//
//  KLineDescriptorFactory.swift
//  SwiftKLine
//
//  Created by zhwayne on 2026/4/27.
//

import CoreGraphics

@MainActor
struct KLineDescriptorFactory {
    func makeDescriptor(
        contentStyle: KLineChartContentStyle,
        mainIndicators: [Indicator],
        subIndicators: [Indicator],
        customRenderers: [AnyRenderer],
        configuration: KLineConfiguration,
        layoutMetrics: LayoutMetrics
    ) -> ChartDescriptor {
        ChartDescriptor {
            RendererGroup(
                chartSection: .mainChart,
                height: layoutMetrics.mainChartHeight,
                padding: (16, 12)
            ) {
                XAxisRenderer()
                if contentStyle == .timeSeries {
                    TimeSeriesRenderer(style: TimeSeriesStyle())
                    YAxisRenderer()
                } else {
                    CandleRenderer()
                    for type in mainIndicators {
                        for renderer in IndicatorRendererRegistry.shared.renderers(for: type, configuration: configuration) {
                            renderer
                        }
                    }
                    for renderer in customRenderers {
                        renderer
                    }
                    YAxisRenderer()
                    PriceIndicatorRenderer(style: PriceIndicatorStyle())
                }
            }

            RendererGroup(
                chartSection: .timeline,
                height: layoutMetrics.timelineHeight,
                padding: (0, 0)
            ) {
                TimeAxisRenderer(style: TimeAxisStyle())
            }

            for type in subIndicators {
                RendererGroup(chartSection: .subChart, height: layoutMetrics.indicatorHeight) {
                    XAxisRenderer()
                    for renderer in IndicatorRendererRegistry.shared.renderers(for: type, configuration: configuration) {
                        renderer
                    }
                }
            }
        }
    }
}
