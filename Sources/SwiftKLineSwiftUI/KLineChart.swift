//
//  KLineChart.swift
//  SwiftKLineSwiftUI
//
//  Created by zhwayne on 2025/04/13.
//

#if canImport(UIKit)
import SwiftUI
import SwiftKLineUI
import SwiftKLineCore

/// A SwiftUI adapter with explicit provider identity and automatic subscription teardown.
///
/// Content style and an optional selection binding update in place. Appearance and plugin options are captured
/// at UIView creation; change the SwiftUI view’s identity to replace those creation-time inputs.
@MainActor
public struct KLineChart: UIViewRepresentable {
    private let sourceID: AnyHashable
    private let makeProvider: @MainActor () -> any ChartItemProvider
    private let options: ChartOptions
    private let content: ChartType
    private let indicators: Binding<IndicatorSelectionState>?
    private let onLoadError: ((Error) -> Void)?

    /// Creates an adapter whose source identity is the provider object’s identity.
    ///
    /// Keep the provider instance stable across body evaluations to avoid reloading history and reconnecting the stream.
    /// - Parameters:
    ///   - provider: The stable Sendable provider instance.
    ///   - options: Creation-time appearance, plugins, feature flags, and initial selection.
    ///   - content: Optional dynamic presentation override; nil uses options.content.
    ///   - indicators: Optional two-way selection binding.
    ///   - onLoadError: Main-actor callback for history and recovery request errors.
    public init(provider: any ChartItemProvider, options: ChartOptions = ChartOptions(),
                content: ChartType? = nil, indicators: Binding<IndicatorSelectionState>? = nil,
                onLoadError: ((Error) -> Void)? = nil) {
        self.init(sourceID: ObjectIdentifier(provider), options: options, content: content,
                  indicators: indicators, onLoadError: onLoadError, provider: { provider })
    }

    /// Creates a provider only when the supplied source identity changes.
    ///
    /// - Parameters:
    ///   - sourceID: A stable symbol/period or equivalent data-source identity.
    ///   - options: Creation-time appearance, plugins, feature flags, and initial selection.
    ///   - content: Optional dynamic presentation override.
    ///   - indicators: Optional two-way selection binding.
    ///   - onLoadError: Main-actor callback for history and recovery request errors.
    ///   - provider: Factory invoked on the main actor when sourceID first appears or changes.
    public init<ID: Hashable>(sourceID: ID, options: ChartOptions = ChartOptions(),
                             content: ChartType? = nil, indicators: Binding<IndicatorSelectionState>? = nil,
                             onLoadError: ((Error) -> Void)? = nil,
                             provider: @escaping @MainActor () -> any ChartItemProvider) {
        self.sourceID = AnyHashable(sourceID)
        self.makeProvider = provider
        self.options = options
        self.content = content ?? options.content
        self.indicators = indicators
        self.onLoadError = onLoadError
    }

    /// Creates the UIKit chart; updateUIView binds the provider and dynamic inputs.
    public func makeUIView(context: Context) -> ChartView {
        ChartView(options: options)
    }

    /// Synchronizes source identity, presentation, callbacks, and selection without writing bindings during the update pass.
    public func updateUIView(_ uiView: ChartView, context: Context) {
        uiView.onLoadError = onLoadError
        // Programmatic synchronization must not write SwiftUI state during updateUIView.
        uiView.indicatorSelectionChanged = nil
        if context.coordinator.sourceID != sourceID {
            context.coordinator.sourceID = sourceID
            uiView.loadData(using: makeProvider())
        }
        uiView.setContentStyle(content)
        if let indicators { uiView.setIndicators(indicators.wrappedValue) }
        let binding = indicators
        uiView.indicatorSelectionChanged = { selection in
            if let binding, binding.wrappedValue != selection { binding.wrappedValue = selection }
        }
    }

    /// Uses the proposed width and the UIKit chart’s descriptor-driven height when custom representable sizing is available.
    @available(iOS 16.0, *)
    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: ChartView, context: Context) -> CGSize? {
        uiView.sizeThatFits(CGSize(width: proposal.width ?? uiView.bounds.width,
                                  height: proposal.height ?? uiView.intrinsicContentSize.height))
    }

    /// Stops provider work and clears callbacks when SwiftUI removes the underlying UIKit view.
    public static func dismantleUIView(_ uiView: ChartView, coordinator: Coordinator) {
        uiView.stopDataLoading()
        uiView.onLoadError = nil
        uiView.indicatorSelectionChanged = nil
    }

    /// Creates the identity holder shared by successive SwiftUI value updates.
    public func makeCoordinator() -> Coordinator { Coordinator() }

    /// Stores the last applied source identity without owning a provider or duplicating chart state.
    public final class Coordinator {
        fileprivate var sourceID: AnyHashable?
    }
}
#endif
