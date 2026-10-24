//
//  KLineChartTests.swift
//  SwiftKLineExampleTests
//
//  Created by zhwayne on 2026/10/24.
//

#if canImport(UIKit)
import Foundation
import UIKit
import SwiftUI
import Testing
import SwiftKLine
@testable import SwiftKLineUI

/// A synchronous test counter for CPU work performed by child tasks, not production async state.
private final class TestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func increment() { lock.withLock { value += 1 } }
    var count: Int { lock.withLock { value } }
}

private final class TestSnapshotProvider: ChartItemProvider, Sendable {
    let items: [any ChartItem]
    init(_ items: [any ChartItem]) { self.items = items }
    func fetchChartItems(forPage page: Int) async throws -> [any ChartItem] { page == 0 ? items : [] }
    func fetchChartItems(from start: Date, to end: Date) async throws -> [any ChartItem] { [] }
}

private func testCandle(_ timestamp: Int, _ close: Double) -> Candle {
    Candle(timestamp: timestamp, open: close, high: close + 2, low: close - 2, close: close, volume: 100)
}

@MainActor
private func eventually(_ condition: () -> Bool) async -> Bool {
    for _ in 0..<2_000 {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
    return condition()
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func swiftUIInputsPreserveProviderUntilApplicationChangesPeriod() async throws {
    let factories = TestCounter()
    let model = ChartInputModel(period: .fiveMinutes, indicators: IndicatorSelection(mainIndicatorIDs: [.ma]))
    let host = UIHostingController(rootView: ChartInputHost(model: model, factories: factories))
    let window = showChartHost(host)
    defer { window.isHidden = true }
    let chart = try #require(descendant(of: host.view, as: ChartView.self))
    #expect(await eventually { chart.debugItemTimestamps == [300] })
    #expect(factories.count == 1)
    model.indicators = IndicatorSelection(mainIndicatorIDs: [.ema], subIndicatorIDs: [.vol])
    #expect(await eventually { chart.indicators == model.indicators })
    #expect(factories.count == 1)
    model.refreshToken += 1
    model.period = .oneHour
    #expect(await eventually { chart.debugItemTimestamps == [3600] && factories.count == 2 })
    #expect(model.period == .oneHour)
    #expect(chart.indicators == model.indicators)
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func swiftUIResolutionNeverWritesBackToApplicationState() async throws {
    let factories = TestCounter()
    let requested = IndicatorSelection(mainIndicatorIDs: [.ma, .ema, .ma], subIndicatorIDs: [.vol])
    let model = ChartInputModel(period: .oneMinute, indicators: requested)
    let host = UIHostingController(rootView: ChartInputHost(model: model, factories: factories))
    let window = showChartHost(host)
    defer { window.isHidden = true }
    let chart = try #require(descendant(of: host.view, as: ChartView.self))
    #expect(await eventually { chart.debugItemTimestamps == [60] })
    model.availableIndicators = [.ma, .vol]
    #expect(await eventually { chart.resolvedIndicators.mainIndicatorIDs == [.ma] })
    #expect(model.indicators == requested)
    model.availableIndicators = [.ma, .ema, .vol]
    #expect(await eventually { chart.resolvedIndicators.mainIndicatorIDs == [.ma, .ema] })
    #expect(model.indicators == requested)
    #expect(factories.count == 1)
}

@available(iOS 16.0, *)
@Test(.timeLimit(.minutes(1))) @MainActor func applicationRestoresPreferencesBeforeFirstProviderSession() async throws {
    let store = RecordingPreferenceStore()
    let saved = ChartPreferences(period: .oneHour, indicators: IndicatorSelection(subIndicatorIDs: [.rsi]))
    saved.save(to: store)
    let restored = ChartPreferences.restore(from: store,
        defaults: ChartPreferences(period: .oneMinute, indicators: IndicatorSelection()))
    let model = ChartInputModel(period: restored.period, indicators: restored.indicators)
    let factories = TestCounter()
    let host = UIHostingController(rootView: ChartInputHost(model: model, factories: factories))
    let window = showChartHost(host)
    defer { window.isHidden = true }
    let chart = try #require(descendant(of: host.view, as: ChartView.self))
    #expect(await eventually { chart.debugItemTimestamps == [3600] })
    #expect(chart.indicators == saved.indicators)
    #expect(factories.count == 1)
    #expect(store.writes == 1)
}

@MainActor
private final class ChartInputModel: ObservableObject {
    @Published var period: ChartPeriod
    @Published var indicators: IndicatorSelection
    @Published var availableIndicators: [BuiltInIndicator] = [.ma, .ema, .vol, .rsi]
    @Published var refreshToken = 0
    init(period: ChartPeriod, indicators: IndicatorSelection) {
        self.period = period
        self.indicators = indicators
    }
}

@MainActor
private final class RecordingPreferenceStore: ChartStateStore {
    private let memory = MemoryChartStateStore()
    private(set) var writes = 0
    func data(forKey key: String) -> Data? { memory.data(forKey: key) }
    func set(_ data: Data, forKey key: String) { writes += 1; memory.set(data, forKey: key) }
    func removeValue(forKey key: String) { memory.removeValue(forKey: key) }
}

@available(iOS 16.0, *)
private struct ChartInputHost: View {
    @ObservedObject var model: ChartInputModel
    let factories: TestCounter

    var body: some View {
        let _ = model.refreshToken
        KLineChart(configuration: configuration(for: model.period), indicators: model.indicators.resolved(availableIndicators: model.availableIndicators))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func configuration(for period: ChartPeriod) -> ChartConfiguration {
        let factories = factories
        let source = CandleSource(id: "\(period.identifier):\(period.seconds)", duration: Double(period.seconds)) {
            factories.increment()
            return TestSnapshotProvider([testCandle(period.seconds, 10)])
        }
        return try! ChartConfiguration(source: source, features: [])
    }
}

@MainActor
private func showChartHost<Content: View>(_ host: UIHostingController<Content>) -> UIWindow {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.frame = window.bounds
    host.view.layoutIfNeeded()
    return window
}

@MainActor
private func descendant<ViewType: UIView>(of view: UIView, as type: ViewType.Type) -> ViewType? {
    if let match = view as? ViewType { return match }
    for subview in view.subviews {
        if let match = descendant(of: subview, as: type) { return match }
    }
    return nil
}
#endif
