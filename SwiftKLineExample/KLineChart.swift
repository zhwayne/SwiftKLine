//
//  KLineChart.swift
//  SwiftKLineExample
//
//  Created by zhwayne on 2025/04/13.
//

#if canImport(UIKit)
import SwiftUI
import SwiftKLine

/// Application-owned SwiftUI bridge for the UIKit chart and its independent indicator input.
/// Restore preferences before constructing this view; changes flow into the chart without binding writes.
@MainActor
struct KLineChart: UIViewRepresentable {
    private let configuration: ChartConfiguration
    private let indicators: IndicatorSelection
    private let onLoadError: ((Error) -> Void)?
    private let onPluginError: ((String, Error) -> Void)?

    /// Indicator choices are supplied by the application and default to empty.
    init(configuration: ChartConfiguration, indicators: IndicatorSelection = IndicatorSelection(),
                onLoadError: ((Error) -> Void)? = nil, onPluginError: ((String, Error) -> Void)? = nil) {
        self.configuration = configuration
        self.indicators = indicators
        self.onLoadError = onLoadError
        self.onPluginError = onPluginError
    }

    func makeUIView(context: Context) -> ChartView {
        ChartView(configuration: configuration, indicators: indicators,
                  onLoadError: onLoadError, onPluginError: onPluginError)
    }

    func updateUIView(_ chart: ChartView, context: Context) {
        chart.onLoadError = onLoadError
        chart.onPluginError = onPluginError
        chart.apply(configuration, indicators: indicators)
    }

    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ChartView, context: Context) -> CGSize? {
        uiView.sizeThatFits(CGSize(width: proposal.width ?? uiView.bounds.width,
                                  height: proposal.height ?? uiView.intrinsicContentSize.height))
    }

    static func dismantleUIView(_ uiView: ChartView, coordinator: ()) {
        uiView.shutdown()
    }
}
#endif
