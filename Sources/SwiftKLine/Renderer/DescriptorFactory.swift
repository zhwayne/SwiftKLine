//  DescriptorFactory.swift
//  SwiftKLine
//
//  Created by zhwayne on 2026/4/27.

import CoreGraphics

@MainActor
struct DescriptorFactory {
    func makeDescriptor(
        contentStyle: ChartType,
        mainIndicatorIDs: [IndicatorID],
        subIndicatorIDs: [IndicatorID],
        customRenderers: [AnyRenderer],
        configuration: ChartConfiguration,
        layoutMetrics: LayoutMetrics,
        registry: PluginRegistry = .default
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
                    for id in mainIndicatorIDs {
                        registry.pluginRenderers(for: id, configuration: configuration)
                        registry.renderers(for: .mainIndicator(id), configuration: configuration)
                    }
                    customRenderers
                    registry.renderers(for: .main, configuration: configuration)
                    registry.renderers(for: .overlay, configuration: configuration)
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

            for id in subIndicatorIDs {
                RendererGroup(chartSection: .subChart, height: layoutMetrics.indicatorHeight) {
                    XAxisRenderer()
                    registry.renderers(for: .sub(id), configuration: configuration)
                    registry.pluginRenderers(for: id, configuration: configuration)
                }
            }
        }
    }

    func makeDescriptor(
        contentStyle: ChartType,
        mainIndicators: [BuiltInIndicator],
        subIndicators: [BuiltInIndicator],
        customRenderers: [AnyRenderer],
        configuration: ChartConfiguration,
        layoutMetrics: LayoutMetrics,
        registry: PluginRegistry = .default
    ) -> ChartDescriptor {
        makeDescriptor(
            contentStyle: contentStyle,
            mainIndicatorIDs: mainIndicators.map(\.id),
            subIndicatorIDs: subIndicators.map(\.id),
            customRenderers: customRenderers,
            configuration: configuration,
            layoutMetrics: layoutMetrics,
            registry: registry
        )
    }
}