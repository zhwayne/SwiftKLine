//
//  ChartUpdateTests.swift
//  SwiftKLineTests
//
//  Created by zhwayne on 2026/10/24.
//

#if canImport(UIKit)
import UIKit
import Testing
import SwiftKLineCore
@testable import SwiftKLineUI

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func unchangedBuiltInsDoNotInvalidateDrawingOrCalculation() async throws {
    let selected = IndicatorSelection(mainIndicatorIDs: [.ma])
    let config = try testConfiguration().includingIndicators(selected)
    let coordinator = ChartCoordinator(configuration: config)
    defer { coordinator.shutdown() }
    coordinator.apply(config, initial: true)
    #expect(await eventually { coordinator.snapshot.items.count == 2 })
    await coordinator.waitForRefresh()
    let revision = coordinator.snapshot.revision
    let renderer = try #require(coordinator.plugins.contexts.first?.renderers.first?.2)
    var invalidations = 0
    coordinator.onResources = { _ in invalidations += 1 }
    for _ in 0..<10 { coordinator.apply(config) }
    await coordinator.waitForRefresh()
    #expect(invalidations == 0)
    #expect(coordinator.snapshot.revision == revision)
    #expect(coordinator.plugins.contexts.first?.renderers.first?.2 === renderer)
    var themed = config
    themed.appearance = .themed(.midnight)
    coordinator.apply(themed)
    await coordinator.waitForRefresh()
    #expect(invalidations == 1)
    #expect(coordinator.snapshot.revision == revision)
    #expect(coordinator.plugins.contexts.first?.renderers.first?.2 === renderer)
}

@MainActor private final class ExternalState {
    var redraw = false
    var updates = 0
}
@MainActor private struct ExternalPlugin: ChartPlugin {
    let id = "external"
    let state: ExternalState
    func makeCoordinator() -> Int { 0 }
    func update(coordinator: Int, context: ChartPluginContext) {
        state.updates += 1
        if state.redraw { context.requestRedraw() }
    }
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func customPluginsStillReceiveUpdatesAndCanRequestDrawing() async throws {
    let state = ExternalState()
    let config = try testConfiguration(plugins: [ExternalPlugin(state: state)])
    let coordinator = ChartCoordinator(configuration: config)
    defer { coordinator.shutdown() }
    coordinator.apply(config, initial: true)
    #expect(await eventually { coordinator.snapshot.items.count == 2 })
    await coordinator.waitForRefresh()
    let updates = state.updates
    var invalidations = 0
    coordinator.onResources = { _ in invalidations += 1 }
    coordinator.apply(config)
    #expect(state.updates == updates + 1)
    #expect(invalidations == 0)
    state.redraw = true
    coordinator.apply(config)
    #expect(state.updates == updates + 2)
    #expect(invalidations == 1)
}

private struct UnknownStyle: IndicatorStyle { let color: UIColor }
@Test @MainActor func customStylesWithoutEqualityConservativelyInvalidateDrawing() throws {
    let config = try testConfiguration(items: [], appearance: ChartAppearance(indicatorStyleRegistry: [
        .ma(period: 5): UnknownStyle(color: .orange)
    ]))
    let coordinator = ChartCoordinator(configuration: config)
    defer { coordinator.shutdown() }
    coordinator.apply(config, initial: true)
    var invalidations = 0
    coordinator.onResources = { _ in invalidations += 1 }
    coordinator.apply(config)
    #expect(invalidations == 1)
}

@Test @MainActor func shutdownPermanentlyRejectsNewSessionsAndIndicatorChanges() throws {
    let factories = TestCounter()
    let initial = try testConfiguration(items: [])
    let chart = ChartView(configuration: initial, indicators: IndicatorSelection(mainIndicatorIDs: [.ma]))
    chart.shutdown()
    chart.shutdown()
    let replacement = try ChartConfiguration(source: CandleSource(id: "replacement", duration: 60) {
        factories.increment()
        return SnapshotProvider(items: [])
    }, features: [])
    chart.apply(replacement, indicators: IndicatorSelection(subIndicatorIDs: [.rsi]))
    chart.setIndicators(IndicatorSelection())
    chart.debugInspectCandle(at: 0)
    #expect(factories.count == 0)
    #expect(chart.indicators.mainIndicatorIDs == [.ma])
    #expect(chart.debugSelectedCandleIndex == nil)
    #expect(chart.debugRendererIdentities.isEmpty)
}

@Test @MainActor func stoppedDrawSchedulerCancelsPendingAndFuturePasses() async {
    let scheduler = RedrawScheduler()
    var draws = 0
    scheduler.schedule(.full) { _ in draws += 1 }
    scheduler.stop()
    scheduler.stop()
    scheduler.schedule(.full) { _ in draws += 1 }
    await Task.yield()
    #expect(draws == 0)
}
@Test @MainActor func shutdownDuringConfigurationAnnouncementDoesNotStartAProvider() throws {
    let factories = TestCounter()
    let config = try ChartConfiguration(source: CandleSource(id: "shutdown-during-apply", duration: 60) {
        factories.increment()
        return SnapshotProvider(items: [])
    }, features: [])
    let coordinator = ChartCoordinator(configuration: config)
    coordinator.onResources = { _ in coordinator.shutdown() }
    coordinator.apply(config, initial: true)
    #expect(coordinator.isShutdown)
    #expect(factories.count == 0)
    #expect(coordinator.plugins.contexts.isEmpty)
}
#endif
