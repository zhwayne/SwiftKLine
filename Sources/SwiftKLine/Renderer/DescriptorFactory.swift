//
//  DescriptorFactory.swift
//  SwiftKLine
//
//  Created by zhwayne on 2026/4/27.
//

import CoreGraphics

@MainActor
struct DescriptorFactory {
    func makeDescriptor(
        contentStyle: KLineChartContentStyle,
        mainIndicatorIDs: [KLineIndicatorID],
        subIndicatorIDs: [KLineIndicatorID],
        customRenderers: [AnyRenderer],
        configuration: KLineConfiguration,
        layoutMetrics: LayoutMetrics,
        registry: KLinePluginRegistry = .default
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
                        if let plugin = registry.plugin(for: id) {
                            for renderer in plugin.makeRenderers(configuration: configuration).map({ $0.eraseToAnyRenderer() }) {
                                renderer
                            }
                        }
                        for renderer in registry.renderers(for: .mainIndicator(id), configuration: configuration) {
                            renderer
                        }
                    }
                    for renderer in customRenderers {
                        renderer
                    }
                    for renderer in registry.renderers(for: .main, configuration: configuration) {
                        renderer
                    }
                    for renderer in registry.renderers(for: .overlay, configuration: configuration) {
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

            for id in subIndicatorIDs {
                RendererGroup(chartSection: .subChart, height: layoutMetrics.indicatorHeight) {
                    XAxisRenderer()
                    for renderer in registry.renderers(for: .sub(id), configuration: configuration) {
                        renderer
                    }
                    if let plugin = registry.plugin(for: id) {
                        for renderer in plugin.makeRenderers(configuration: configuration).map({ $0.eraseToAnyRenderer() }) {
                            renderer
                        }
                    }
                }
            }
        }
    }

    func makeDescriptor(
        contentStyle: KLineChartContentStyle,
        mainIndicators: [KLineIndicator],
        subIndicators: [KLineIndicator],
        customRenderers: [AnyRenderer],
        configuration: KLineConfiguration,
        layoutMetrics: LayoutMetrics,
        registry: KLinePluginRegistry = .default
    ) -> ChartDescriptor {
        makeDescriptor(
            contentStyle: contentStyle,
            mainIndicatorIDs: mainIndicators.map(\.kLineID),
            subIndicatorIDs: subIndicators.map(\.kLineID),
            customRenderers: customRenderers,
            configuration: configuration,
            layoutMetrics: layoutMetrics,
            registry: registry
        )
    }
}
