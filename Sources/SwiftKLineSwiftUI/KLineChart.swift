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

/// A SwiftUI chart with one binding for period and indicator selection.
@MainActor
public struct KLineChart: UIViewRepresentable {
    @Binding private var selection: ChartSelection
    private let hasSelectionBinding: Bool
    private let availablePeriods: [ChartPeriod]
    private let stateStore: (any ChartStateStore)?
    private let configuration: (ChartSelection) -> ChartConfiguration
    private let onLoadError: ((Error) -> Void)?
    private let onPluginError: ((String, Error) -> Void)?

    /// Creates a manually configured chart without external selection controls.
    public init(configuration: ChartConfiguration, stateStore: (any ChartStateStore)? = nil,
                onLoadError: ((Error) -> Void)? = nil, onPluginError: ((String, Error) -> Void)? = nil) {
        let defaults = IndicatorSelection(mainIndicators: configuration.appearance.defaultMainIndicators,
                                          subIndicators: configuration.appearance.defaultSubIndicators)
        _selection = .constant(ChartSelection(period: .oneMinute, indicators: defaults))
        hasSelectionBinding = false
        availablePeriods = []
        self.stateStore = stateStore
        self.configuration = { _ in configuration }
        self.onLoadError = onLoadError
        self.onPluginError = onPluginError
    }

    /// Restores selection before the configuration factory creates the first source session.
    /// Resolved state is written back asynchronously; later binding edits use the same normalization and storage path.
    public init(selection: Binding<ChartSelection>, availablePeriods: [ChartPeriod] = [],
                stateStore: (any ChartStateStore)? = nil,
                configuration: @escaping (ChartSelection) -> ChartConfiguration,
                onLoadError: ((Error) -> Void)? = nil, onPluginError: ((String, Error) -> Void)? = nil) {
        _selection = selection
        hasSelectionBinding = true
        self.availablePeriods = availablePeriods
        self.stateStore = stateStore
        self.configuration = configuration
        self.onLoadError = onLoadError
        self.onPluginError = onPluginError
    }

    public func makeUIView(context: Context) -> ChartView {
        let chart = ChartView(selection: selection, availablePeriods: availablePeriods,
            stateStore: stateStore, configuration: configuration,
            onLoadError: onLoadError, onPluginError: onPluginError)
        context.coordinator.lastInput = selection
        installSelectionObserver(on: chart, coordinator: context.coordinator)
        if hasSelectionBinding { context.coordinator.publish(chart.selection, to: $selection) }
        return chart
    }

    public func updateUIView(_ chart: ChartView, context: Context) {
        let coordinator = context.coordinator
        let incoming = selection
        var command: ChartSelection?
        if !hasSelectionBinding { coordinator.cancelPendingBindingWrite() }
        if hasSelectionBinding, incoming != coordinator.lastInput {
            if incoming == coordinator.pendingSelection {
                coordinator.acknowledgeBindingWrite()
            } else {
                coordinator.cancelPendingBindingWrite()
                command = incoming
            }
        }
        coordinator.lastInput = incoming
        chart.selectionChanged = nil
        chart.onLoadError = onLoadError
        chart.onPluginError = onPluginError
        chart.apply(selection: command, availablePeriods: availablePeriods, configuration: configuration)
        installSelectionObserver(on: chart, coordinator: coordinator)
        if hasSelectionBinding { coordinator.publish(chart.selection, to: $selection) }
    }

    @available(iOS 16.0, *)
    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: ChartView, context: Context) -> CGSize? {
        uiView.sizeThatFits(CGSize(width: proposal.width ?? uiView.bounds.width,
                                  height: proposal.height ?? uiView.intrinsicContentSize.height))
    }

    public static func dismantleUIView(_ uiView: ChartView, coordinator: Coordinator) {
        uiView.selectionChanged = nil
        coordinator.cancelPendingBindingWrite()
        uiView.shutdown()
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    private func installSelectionObserver(on chart: ChartView, coordinator: Coordinator) {
        guard hasSelectionBinding else { chart.selectionChanged = nil; return }
        let binding = $selection
        chart.selectionChanged = { [weak coordinator] value in coordinator?.publish(value, to: binding) }
    }

    @MainActor public final class Coordinator {
        fileprivate var lastInput: ChartSelection?
        fileprivate var pendingSelection: ChartSelection?
        private var bindingWriteTask: Task<Void, Never>?

        fileprivate func publish(_ selection: ChartSelection, to binding: Binding<ChartSelection>) {
            let input = binding.wrappedValue
            guard input != selection else { cancelPendingBindingWrite(); return }
            guard pendingSelection != selection else { return }
            cancelPendingBindingWrite()
            pendingSelection = selection
            bindingWriteTask = Task { @MainActor [weak self] in
                await Task.yield()
                guard !Task.isCancelled, let self else { return }
                // A newer user command wins over an outstanding hydration/normalization write.
                guard binding.wrappedValue == input else { self.cancelPendingBindingWrite(); return }
                binding.wrappedValue = selection
            }
        }

        fileprivate func acknowledgeBindingWrite() {
            cancelPendingBindingWrite()
        }

        fileprivate func cancelPendingBindingWrite() {
            bindingWriteTask?.cancel()
            bindingWriteTask = nil
            pendingSelection = nil
        }
    }
}
#endif
