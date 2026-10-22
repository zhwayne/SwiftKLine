//
//  KLineChart.swift
//  SwiftKLineSwiftUI
//
//  Created by zhwayne on 2025/04/13.
//

#if canImport(UIKit)
import SwiftUI
import SwiftKLineUI

/// A thin SwiftUI adapter sharing UIKit's configuration reconciliation and lifecycle.
@MainActor
public struct KLineChart: UIViewRepresentable {
    /// The complete declarative input, owned by the application.
    public let configuration: ChartConfiguration
    private let indicators: Binding<IndicatorSelectionState>?
    private let onLoadError: ((Error) -> Void)?
    private let onPluginError: ((String, Error) -> Void)?

    /// Creates an adapter with optional candle and plugin error callbacks.
    public init(configuration: ChartConfiguration, indicators: Binding<IndicatorSelectionState>? = nil, onLoadError: ((Error) -> Void)? = nil,
                onPluginError: ((String, Error) -> Void)? = nil) {
        self.configuration = configuration
        self.indicators = indicators
        self.onLoadError = onLoadError
        self.onPluginError = onPluginError
    }
    /// Creates the same UIKit host used by direct UIKit clients.
    public func makeUIView(context: Context) -> ChartView {
        ChartView(configuration: configuration, onLoadError: onLoadError, onPluginError: onPluginError)
    }
    /// Reconciles configuration without recreating unchanged provider sessions.
    public func updateUIView(_ uiView: ChartView, context: Context) {
        context.coordinator.isSynchronizing = true
        defer { context.coordinator.isSynchronizing = false }
        uiView.indicatorSelectionChanged = nil
        uiView.onLoadError = onLoadError
        uiView.onPluginError = onPluginError
        uiView.apply(configuration)
        if let indicators, uiView.indicatorSelection != indicators.wrappedValue {
            uiView.setIndicators(indicators.wrappedValue)
        }
        let binding = indicators
        let coordinator = context.coordinator
        uiView.indicatorSelectionChanged = { [weak coordinator] value in
            guard coordinator?.isSynchronizing == false else { return }
            if let binding, binding.wrappedValue != value { binding.wrappedValue = value }
        }
    }
    /// Uses the proposed width and the UIKit host’s intrinsic panel and selector height.
    @available(iOS 16.0, *)
    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: ChartView, context: Context) -> CGSize? {
        uiView.sizeThatFits(CGSize(width: proposal.width ?? uiView.bounds.width,
                                  height: proposal.height ?? uiView.intrinsicContentSize.height))
    }
    /// Ends owned sessions before SwiftUI releases the UIKit host.
    public static func dismantleUIView(_ uiView: ChartView, coordinator: Coordinator) {
        uiView.indicatorSelectionChanged = nil
        uiView.shutdown()
    }
    /// Creates binding synchronization state without owning a second loading session.
    public func makeCoordinator() -> Coordinator { Coordinator() }
    /// Prevents binding feedback while UIKit is synchronizing declared state.
    @MainActor public final class Coordinator { fileprivate var isSynchronizing = false }
}
#endif
