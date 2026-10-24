//
//  ChartInvalidation.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/10/24.
//

/// The distinct kinds of work one configuration change can require.
///
/// Configuration differences used to be recomputed by each consumer: the view compared source,
/// candle dimensions, content, and layout metrics, while the coordinator re-derived the same
/// source and appearance predicates. Both layers now use the same comparison logic to decide
/// which change restarts a session, which rebuilds geometry, and which only redraws.
@MainActor
struct ChartInvalidation: Equatable {
    /// The primary candle session must stop and restart because its identity or loading capabilities changed.
    let restartsCandleSession: Bool
    /// The configured candle dimensions changed: re-seed gesture-managed candle width and gap.
    let candleDimensionsChanged: Bool
    /// Section heights, main-chart content, or candle dimensions changed: rebuild geometry and clear the crosshair.
    let geometryChanged: Bool
    /// Any appearance input changed: existing layers must be redrawn.
    let appearanceChanged: Bool

    /// Whether applying this configuration must invalidate drawing at all.
    ///
    /// Source, geometry, and appearance changes each require drawing to be invalidated.
    var requiresRedraw: Bool { restartsCandleSession || geometryChanged || appearanceChanged }

    /// Compares the configuration a chart already applied with the one it is about to apply.
    ///
    /// Only fields owned by the declared configuration participate. Indicators arrive as an extra
    /// argument and never change these inputs, so both the declared and the effective configuration
    /// yield the same result.
    init(from old: ChartConfiguration, to new: ChartConfiguration) {
        restartsCandleSession = old.source.id != new.source.id
            || old.features.intersection(.candleLoading) != new.features.intersection(.candleLoading)
        candleDimensionsChanged = old.appearance.candleStyle.width != new.appearance.candleStyle.width
            || old.appearance.candleStyle.gap != new.appearance.candleStyle.gap
        geometryChanged = old.content != new.content
            || old.appearance.layoutMetrics != new.appearance.layoutMetrics
            || candleDimensionsChanged
        appearanceChanged = !old.appearance.hasSameVisuals(as: new.appearance)
    }
}
