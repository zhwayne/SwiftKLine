//
//  ArchitectureRefactorTests.swift
//  SwiftKLineTests
//
//  Created by zhwayne on 2026/05/17.
//

#if canImport(UIKit)
import Foundation
import UIKit
import Testing
import SwiftKLineCore
@testable import SwiftKLineUI

@MainActor private final class Recorder {
    var created: [ObjectIdentifier] = []
    var dismantled = 0
    var installed = 0
    var uninstalled = 0
    var contexts: [String: ChartPluginContext] = [:]
    var draws: [String: ContiguousArray<Double?>] = [:]
    let calculations = TestCounter()
}
private let probeKey = SeriesKey(indicatorID: "probe", name: "value")
private struct ProbeCalculator: IndicatorCalculator {
    let id = probeKey
    let factor: Double
    let calls: TestCounter
    func calculate(for items: [any ChartItem]) -> [Double?] {
        calls.increment()
        return items.map { $0.close * factor }
    }
}
@MainActor private final class ProbeRenderer: ChartRenderer {
    let id = "same-semantic-id"
    let plugin: String
    let recorder: Recorder
    init(plugin: String, recorder: Recorder) { self.plugin = plugin; self.recorder = recorder }
    func install(to layer: CALayer) { recorder.installed += 1 }
    func uninstall(from layer: CALayer) { recorder.uninstalled += 1 }
    func draw(in layer: CALayer, context: ChartContext) {
        recorder.draws[plugin] = context.values(for: probeKey, as: Double.self)
    }
}
@MainActor private struct ProbePlugin: ChartPlugin {
    let id: String
    var factor: Double = 1
    var colorVersion = 0
    var panel: PluginPanel = .main
    let recorder: Recorder
    @MainActor final class Coordinator { var factor: Double?; var color: Int? }
    func makeCoordinator() -> Coordinator {
        let value = Coordinator(); recorder.created.append(ObjectIdentifier(value)); return value
    }
    func update(coordinator: Coordinator, context: ChartPluginContext) {
        recorder.contexts[id] = context
        if coordinator.factor != factor {
            coordinator.factor = factor
            context.setCalculator(ProbeCalculator(factor: factor, calls: recorder.calculations), for: "values")
        }
        if coordinator.color != colorVersion {
            coordinator.color = colorVersion
            context.setRenderer(ProbeRenderer(plugin: id, recorder: recorder), for: "drawing", panel: panel)
        }
    }
    static func dismantleCoordinator(_ coordinator: Coordinator) {}
}
@MainActor private struct EmptyPlugin: ChartPlugin {
    let id: String
    func update(coordinator: Void, context: ChartPluginContext) {}
}

@Test @MainActor func duplicateAndEmptyPluginIDsAreRejected() throws {
    #expect(throws: ChartConfigurationError.duplicatePluginID("same")) {
        try testConfiguration(plugins: [EmptyPlugin(id: "same"), EmptyPlugin(id: "same")])
    }
    #expect(throws: ChartConfigurationError.emptyPluginID) {
        try testConfiguration(plugins: [EmptyPlugin(id: "")])
    }
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func pluginOutputsAndRendererIDsAreIsolated() async throws {
    let recorder = Recorder()
    let chart = ChartView(configuration: try testConfiguration(plugins: [
        ProbePlugin(id: "a", factor: 2, recorder: recorder), ProbePlugin(id: "b", factor: 3, recorder: recorder)]))
    #expect(await eventually { chart.debugItemTimestamps.count == 2 })
    await chart.debugWaitForRefresh()
    #expect(chart.debugStore(for: "a").values(for: probeKey, as: Double.self) == [2, 4])
    #expect(chart.debugStore(for: "b").values(for: probeKey, as: Double.self) == [3, 6])
    chart.frame = CGRect(x: 0, y: 0, width: 300, height: chart.intrinsicContentSize.height)
    _ = chart.debugRenderForInspection()
    #expect(recorder.draws["a"] == [2, 4])
    #expect(recorder.draws["b"] == [3, 6])
    #expect(recorder.installed == 2)
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func appearanceAndExternalRedrawDoNotRecalculate() async throws {
    let recorder = Recorder(), factories = TestCounter()
    let source = CandleSource(id: "stable", duration: 60) { factories.increment(); return TestSnapshotProvider([testCandle(60, 1)]) }
    let plugin = ProbePlugin(id: "a", recorder: recorder)
    var config = try ChartConfiguration(source: source, plugins: [plugin], features: [])
    let chart = ChartView(configuration: config)
    #expect(await eventually { chart.debugItemTimestamps.count == 1 })
    await chart.debugWaitForRefresh()
    let calls = recorder.calculations.count
    config.appearance = .themed(.solaris)
    chart.apply(config)
    recorder.contexts["a"]?.requestRedraw()
    await chart.debugWaitForRefresh()
    #expect(recorder.calculations.count == calls)
    #expect(factories.count == 1)
    #expect(recorder.created.count == 1)
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func rendererReplacementWithSameSemanticIDActuallyReplacesIt() async throws {
    let recorder = Recorder()
    let chart = ChartView(configuration: try testConfiguration(plugins: [ProbePlugin(id: "a", recorder: recorder)]))
    #expect(await eventually { chart.debugItemTimestamps.count == 2 })
    let calls = recorder.calculations.count
    chart.apply(try testConfiguration(plugins: [ProbePlugin(id: "a", colorVersion: 1, recorder: recorder)]))
    #expect(recorder.installed == 2)
    #expect(recorder.uninstalled == 1)
    #expect(recorder.created.count == 1)
    #expect(recorder.calculations.count == calls)
}

@MainActor private struct AveragePlugin: ChartPlugin {
    let id: String
    let period: Int
    @MainActor final class Coordinator { var period: Int? }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func update(coordinator: Coordinator, context: ChartPluginContext) {
        guard coordinator.period != period else { return }
        coordinator.period = period
        context.setCalculator(MACalculator(period: period), for: "average")
    }
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func parameterChangesReplaceOnlyTheirOwnOutput() async throws {
    let chart = ChartView(configuration: try testConfiguration(plugins: [
        AveragePlugin(id: "a", period: 1), AveragePlugin(id: "b", period: 1)]))
    #expect(await eventually { chart.debugItemTimestamps.count == 2 })
    chart.apply(try testConfiguration(plugins: [AveragePlugin(id: "a", period: 2), AveragePlugin(id: "b", period: 1)]))
    await chart.debugWaitForRefresh()
    #expect(chart.debugStore(for: "a").values(for: .ma(period: 2), as: Double.self) == [nil, 1.5])
    #expect(chart.debugStore(for: "a").values(for: .ma(period: 1), as: Double.self) == nil)
    #expect(chart.debugStore(for: "b").values(for: .ma(period: 1), as: Double.self) == [1, 2])
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func removedContextCannotReinstallResources() async throws {
    let recorder = Recorder()
    let chart = ChartView(configuration: try testConfiguration(plugins: [ProbePlugin(id: "a", recorder: recorder)]))
    #expect(await eventually { chart.debugItemTimestamps.count == 2 })
    let context = try #require(recorder.contexts["a"])
    chart.apply(try testConfiguration(plugins: [EmptyPlugin(id: "a")]))
    await chart.debugWaitForRefresh()
    let calls = recorder.calculations.count
    context.setCalculator(ProbeCalculator(factor: 100, calls: recorder.calculations), for: "late")
    context.requestRedraw()
    await chart.debugWaitForRefresh()
    #expect(!context.isValid)
    #expect(recorder.calculations.count == calls)
    #expect(recorder.uninstalled == 1)
    #expect(chart.debugStore(for: "a").values(for: probeKey, as: Double.self) == nil)
}

@Test @MainActor func reorderingPreservesCoordinatorsAndRendererObjects() throws {
    let recorder = Recorder()
    let a = ProbePlugin(id: "a", recorder: recorder), b = ProbePlugin(id: "b", recorder: recorder)
    let chart = ChartView(configuration: try testConfiguration(plugins: [a, b]))
    let identities = chart.debugRendererIdentities
    chart.apply(try testConfiguration(plugins: [b, a]))
    #expect(recorder.created.count == 2)
    #expect(recorder.installed == 2)
    #expect(recorder.uninstalled == 0)
    #expect(Set(chart.debugRendererIdentities) == Set(identities))
}

@Test @MainActor func oneConfigurationCreatesIndependentCharts() throws {
    let recorder = Recorder(), factories = TestCounter()
    let source = CandleSource(id: "shared-definition", duration: 60) { factories.increment(); return TestSnapshotProvider([]) }
    let config = try ChartConfiguration(source: source, plugins: [ProbePlugin(id: "a", recorder: recorder)], features: [])
    let first = ChartView(configuration: config), second = ChartView(configuration: config)
    #expect(factories.count == 2)
    #expect(Set(recorder.created).count == 2)
    #expect(Set(first.debugRendererIdentities).isDisjoint(with: Set(second.debugRendererIdentities)))
}

@Test @MainActor func unchangedSourceIdentityIgnoresNewFactories() throws {
    let first = TestCounter(), second = TestCounter()
    func config(_ counter: TestCounter) throws -> ChartConfiguration {
        try ChartConfiguration(source: CandleSource(id: "same", duration: 60) {
            counter.increment(); return TestSnapshotProvider([])
        }, features: [])
    }
    let chart = ChartView(configuration: try config(first))
    chart.apply(try config(second))
    #expect(first.count == 1)
    #expect(second.count == 0)
}

@Test @MainActor func changingTheSourceRecreatesCoordinators() throws {
    let recorder = Recorder()
    let chart = ChartView(configuration: try testConfiguration(id: "one", plugins: [ProbePlugin(id: "a", recorder: recorder)]))
    let previous = try #require(recorder.contexts["a"])
    chart.apply(try testConfiguration(id: "two", plugins: [ProbePlugin(id: "a", recorder: recorder)]))
    #expect(recorder.created.count == 2)
    #expect(!previous.isValid)
    #expect(chart.debugItemTimestamps.isEmpty)
}

@MainActor private struct DuplicateSeriesPlugin: ChartPlugin {
    let id = "duplicate-series"
    @MainActor final class Coordinator { var configured = false }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func update(coordinator: Coordinator, context: ChartPluginContext) {
        guard !coordinator.configured else { return }
        coordinator.configured = true
        context.setCalculator(MACalculator(period: 1), for: "first")
        context.setCalculator(MACalculator(period: 1), for: "second")
    }
}

@Test @MainActor func synchronousPluginDeclarationErrorsReachTheInitialHandler() throws {
    var failures: [(String, ChartPluginError)] = []
    let chart = ChartView(configuration: try testConfiguration(plugins: [DuplicateSeriesPlugin()]),
                          onPluginError: { id, error in
        if let error = error as? ChartPluginError { failures.append((id, error)) }
    })
    #expect(failures.count == 1)
    #expect(failures.first?.0 == "duplicate-series")
    #expect(failures.first?.1 == .duplicateSeries(.ma(period: 1)))
    chart.shutdown()
}
@Test @MainActor func viewportAndActivityInputsDoNotInvalidateUnchangedResources() throws {
    let configuration = try testConfiguration(plugins: [EmptyPlugin(id: "passive")])
    let coordinator = ChartCoordinator(configuration: configuration)
    var notifications: [Bool] = []
    coordinator.onResources = { notifications.append($0) }
    coordinator.apply(configuration, initial: true)
    notifications.removeAll()
    for offset in 0..<20 { coordinator.setVisibleRange(offset..<(offset + 10)) }
    coordinator.setActive(false)
    coordinator.setActive(true)
    #expect(notifications.isEmpty)

    // Explicit drawing invalidation and new appearance configurations must still reach the host.
    let context = try #require(coordinator.plugins.contexts.first)
    context.requestRedraw()
    #expect(notifications == [false])
    coordinator.apply(configuration)
    #expect(notifications == [false, false])
    coordinator.shutdown()
}
@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func builtInOnlyScrollingSkipsUnusedDemandButCustomPluginsReceiveIt() async throws {
    let boundaries = TestCounter()
    let source = CandleSource(id: "demand", candleInterval: { timestamp in
        boundaries.increment()
        let start = Date(timeIntervalSince1970: Double(timestamp))
        return start..<start.addingTimeInterval(60)
    }, provider: { TestSnapshotProvider((0..<100).map { testCandle($0 * 60, Double($0)) }) })
    let selection = IndicatorSelection(mainIndicatorIDs: [.ma])
    let chart = ChartView(configuration: try ChartConfiguration(source: source, features: []), selection: testSelection(selection))
    #expect(await eventually { chart.debugItemTimestamps.count == 100 })
    chart.frame = CGRect(x: 0, y: 0, width: 390, height: chart.intrinsicContentSize.height)
    _ = chart.debugRenderForInspection()
    #expect(boundaries.count == 0)

    func findScrollView(in view: UIView) -> ChartScrollView? {
        if let scroll = view as? ChartScrollView { return scroll }
        return view.subviews.lazy.compactMap { findScrollView(in: $0) }.first
    }
    let scroll = try #require(findScrollView(in: chart))
    scroll.contentOffset.x = 200
    scroll.setNeedsLayout(); scroll.layoutIfNeeded()
    #expect(boundaries.count == 0)

    let recorder = Recorder()
    chart.apply(try ChartConfiguration(source: source,
        plugins: [ProbePlugin(id: "custom", recorder: recorder)], features: []))
    let before = boundaries.count
    scroll.contentOffset.x = 400
    scroll.setNeedsLayout(); scroll.layoutIfNeeded()
    #expect(boundaries.count > before)
    #expect(recorder.contexts["custom"]?.input.visibleTimeRange != nil)
    chart.shutdown()
}
#endif
