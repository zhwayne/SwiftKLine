//
//  TradeMarkers.swift
//  SwiftKLineExample
//
//  Created by zhwayne on 2026/10/21.
//

#if canImport(UIKit)
import SwiftKLine
import UIKit

/// Point appearance; price-axis participation is an explicit opt-in.
struct TradeMarkerStyle: Equatable {
    /// Fill color of buy markers.
    var buyColor: UIColor
    /// Fill color of sell markers.
    var sellColor: UIColor
    /// Marker diameter in points.
    var size: CGFloat
    /// Whether visible event prices expand the chart value range.
    var includesPricesInBounds: Bool
    /// Creates marker appearance with a finite positive size.
    init(buyColor: UIColor = .systemGreen, sellColor: UIColor = .systemRed,
                size: CGFloat = 8, includesPricesInBounds: Bool = false) {
        precondition(size.isFinite && size > 0)
        self.buyColor = buyColor; self.sellColor = sellColor
        self.size = size; self.includesPricesInBounds = includesPricesInBounds
    }
}

/// Independently paged executions, attached through the same lifecycle as calculated indicators.
@MainActor
struct TradeMarkers<Provider: RangeDataProvider>: ChartPlugin where Provider.Item == TradeMarker {
    /// Stable identity in the chart plugin list.
    let id: String
    /// Semantic account/query identity; changing it replaces only this range session.
    let sourceID: String
    /// Creates one independent provider per data session.
    private let provider: @Sendable () -> Provider
    /// Marker appearance, updated without refetching data or recalculating indicators.
    var style: TradeMarkerStyle
    /// Change this value to retry a failed cursor without discarding completed cache coverage.
    var retryID: Int
    /// Hard item limit for the independent cache; overflowing visible demand reports an error.
    let maxCachedItems: Int

    /// Creates a marker plugin whose provider output is checked against TradeMarker at compile time.
    init(id: String = "trades", sourceID: String, style: TradeMarkerStyle = TradeMarkerStyle(),
                retryID: Int = 0, maxCachedItems: Int = 20_000,
                provider: @escaping @Sendable () -> Provider) {
        precondition(maxCachedItems > 0)
        self.id = id; self.sourceID = sourceID; self.provider = provider
        self.style = style; self.retryID = retryID; self.maxCachedItems = maxCachedItems
    }

    /// Coordinates demand, an isolated range loader, and two reusable marker layers.
    @MainActor
    final class Coordinator {
        fileprivate let renderer = TradeMarkerRenderer()
        fileprivate var loader: RangeLoader<Provider, String>?
        fileprivate var sourceID: String?
        fileprivate var capacity: Int?
        fileprivate var retryID = 0
        fileprivate var context: ChartPluginContext?
        fileprivate var generation = UUID()
        fileprivate var pending: (Range<Date>?, Bool, Bool)?
        fileprivate var commandTask: Task<Void, Never>?
        fileprivate var lastRange: Range<Date>?
        fileprivate var lastActive: Bool?

        fileprivate func stop() {
            generation = UUID()
            commandTask?.cancel(); commandTask = nil; pending = nil
            let old = loader; loader = nil
            Task { await old?.stop() }
            context = nil
        }

        /// One bounded command driver preserves ordering across actor hops and coalesces viewport changes.
        fileprivate func submit(range: Range<Date>?, active: Bool, retry: Bool) {
            guard lastRange != range || lastActive != active || retry else { return }
            lastRange = range; lastActive = active
            pending = (range, active, retry || (pending?.2 ?? false))
            guard commandTask == nil else { return }
            let generation = generation
            commandTask = Task { [weak self] in await self?.drain(generation: generation) }
        }
        private func drain(generation: UUID) async {
            while !Task.isCancelled, generation == self.generation, let command = pending {
                pending = nil
                guard let loader else { break }
                await loader.setActive(command.1)
                guard !Task.isCancelled, generation == self.generation else { return }
                if command.2 { await loader.retry() }
                if let range = command.0 { await loader.load(in: range) }
            }
            if generation == self.generation { commandTask = nil }
        }
    }

    /// Creates isolated loading and rendering state for one chart.
    func makeCoordinator() -> Coordinator { Coordinator() }
    /// Reconciles account identity, marker appearance, retry requests, and current demand.
    func update(coordinator: Coordinator, context: ChartPluginContext) {
        coordinator.context = context
        if coordinator.sourceID != sourceID || coordinator.capacity != maxCachedItems {
            coordinator.stop()
            coordinator.context = context
            coordinator.sourceID = sourceID; coordinator.capacity = maxCachedItems
            coordinator.lastActive = nil; coordinator.lastRange = nil
            coordinator.renderer.items = []
            let generation = coordinator.generation
            coordinator.loader = RangeLoader(provider: provider(), maxCachedItems: maxCachedItems,
                identity: { $0.id }, timestamp: { $0.timestamp }) { [weak coordinator] snapshot in
                    guard let coordinator, coordinator.generation == generation,
                          coordinator.context != nil else { return }
                    coordinator.renderer.items = snapshot.items
                    coordinator.context?.requestRedraw()
                    if let error = snapshot.error { coordinator.context?.report(error) }
                }
            context.setRenderer(coordinator.renderer, for: "markers", panel: .main)
            context.requestRedraw()
        }
        if coordinator.renderer.style != style {
            coordinator.renderer.style = style
            context.requestRedraw()
        }
        let retry = coordinator.retryID != retryID
        coordinator.retryID = retryID
        coordinator.submit(range: context.input.visibleTimeRange, active: context.input.isActive, retry: retry)
    }
    /// Cancels owned requests and releases retained chart capabilities.
    static func dismantleCoordinator(_ coordinator: Coordinator) { coordinator.stop() }
}

/// Draws only events in the visible time interval; missing candle buckets are never inferred.
@MainActor
final class TradeMarkerRenderer: ChartRenderer {
    let id = "trade-markers"
    let zIndex = 10
    var style = TradeMarkerStyle()
    var items: [TradeMarker] = []
    private let viewport = CALayer()
    private let buys = CAShapeLayer()
    private let sells = CAShapeLayer()
    init() {
        viewport.masksToBounds = true
        viewport.addSublayer(buys); viewport.addSublayer(sells)
    }
    func install(to layer: CALayer) { layer.addSublayer(viewport) }
    func uninstall(from layer: CALayer) { viewport.removeFromSuperlayer() }

    private func visible(_ context: ChartContext) -> ArraySlice<TradeMarker> {
        guard let range = context.visibleTimeRange else { return [] }
        func lowerBound(_ date: Date) -> Int {
            var low = 0, high = items.count
            while low < high {
                let middle = low + (high - low) / 2
                if items[middle].timestamp < date { low = middle + 1 } else { high = middle }
            }
            return low
        }
        return items[lowerBound(range.lowerBound)..<lowerBound(range.upperBound)]
    }
    func draw(in layer: CALayer, context: ChartContext) {
        viewport.frame = context.viewPort
        let buyPath = CGMutablePath(), sellPath = CGMutablePath()
        for marker in visible(context) where marker.price.isFinite {
            guard let index = context.candleIndex(containing: marker.timestamp), context.visibleRange.contains(index) else { continue }
            let x = context.layout.xPosition(at: index - context.visibleRange.lowerBound) + context.candleWidth / 2 - context.viewPort.minX
            let y = context.layout.yPosition(for: marker.price, viewPort: context.viewPort) - context.viewPort.minY
            guard x.isFinite, y.isFinite, style.size.isFinite, style.size > 0 else { continue }
            let radius = style.size / 2
            let direction: CGFloat = marker.side == .buy ? 1 : -1
            let path = marker.side == .buy ? buyPath : sellPath
            path.move(to: CGPoint(x: x, y: y - radius * direction))
            path.addLine(to: CGPoint(x: x - radius, y: y + radius * direction))
            path.addLine(to: CGPoint(x: x + radius, y: y + radius * direction))
            path.closeSubpath()
        }
        buys.path = buyPath; sells.path = sellPath
        buys.fillColor = style.buyColor.cgColor; sells.fillColor = style.sellColor.cgColor
    }
    func dataBounds(context: ChartContext) -> ValueBounds {
        guard style.includesPricesInBounds else { return .empty }
        var result = ValueBounds.empty
        for marker in visible(context) where marker.price.isFinite {
            guard let index = context.candleIndex(containing: marker.timestamp), context.visibleRange.contains(index) else { continue }
            result.merge(other: ValueBounds(min: marker.price, max: marker.price))
        }
        return result
    }
}
#endif
