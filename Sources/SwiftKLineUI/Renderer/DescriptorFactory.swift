//
//  DescriptorFactory.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/04/27.
//

import SwiftKLineCore
import UIKit

/// Assembles reusable main, timeline, and per-plugin lower panels.
@MainActor
struct DescriptorFactory {
    func makeDescriptor(content: ChartType, appearance: ChartAppearance,
                        contexts: [ChartPluginContext]) -> ChartDescriptor {
        let timeSeriesStyle = TimeSeriesStyle()
        func renderers(_ context: ChartPluginContext, panel: PluginPanel) -> [AnyRenderer] {
            context.renderers.filter { $0.1 == panel }.map {
                PluginRenderer(plugin: context.id, local: $0.0, renderer: $0.2).eraseToAnyRenderer()
            }
        }
        return ChartDescriptor {
            RendererGroup(chartSection: .mainChart, height: appearance.layoutMetrics.mainChartHeight, padding: (16, 12)) {
                XAxisRenderer()
                if content == .timeSeries { TimeSeriesRenderer(style: timeSeriesStyle) }
                else { CandleRenderer() }
                for context in contexts {
                    // Preserve the original time-series UI; independent custom overlays remain supported.
                    if content != .timeSeries || BuiltInIndicator(id: IndicatorID(context.id)) == nil {
                        renderers(context, panel: .main)
                    }
                }
                YAxisRenderer()
                PriceIndicatorRenderer(style: PriceIndicatorStyle(), showsExtremes: content != .timeSeries,
                    latestPointColor: content == .timeSeries ? timeSeriesStyle.lineColor : nil)
            }
            RendererGroup(chartSection: .timeline, height: appearance.layoutMetrics.timelineHeight, padding: (0, 0)) {
                TimeAxisRenderer(style: TimeAxisStyle())
            }
            for context in contexts where context.renderers.contains(where: { $0.1 == .sub }) {
                RendererGroup(chartSection: .subChart, height: appearance.layoutMetrics.indicatorHeight) {
                    XAxisRenderer()
                    renderers(context, panel: .sub)
                }
            }
        }
    }
}
