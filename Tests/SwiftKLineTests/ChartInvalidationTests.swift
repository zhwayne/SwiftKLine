//
//  ChartInvalidationTests.swift
//  SwiftKLineTests
//
//  Created by zhwayne on 2026/10/24.
//

#if canImport(UIKit)
import Foundation
import Testing
@testable import SwiftKLineCore
@testable import SwiftKLineUI

/// Builds configuration pairs that differ in exactly one input.
@MainActor
private enum InvalidationFixture {
    static func configuration(
        sourceID: String = "offline",
        features: ChartFeatures = .all,
        content: ChartType = .candlestick,
        appearance: ChartAppearance = ChartAppearance()
    ) throws -> ChartConfiguration {
        try ChartConfiguration(
            source: CandleSource(id: sourceID, duration: 60) { SnapshotProvider(items: []) },
            appearance: appearance,
            content: content,
            features: features
        )
    }
}

@MainActor
@Suite("Chart configuration invalidation")
struct ChartInvalidationTests {

    @Test func identicalConfigurationInvalidatesNothing() throws {
        let configuration = try InvalidationFixture.configuration()
        let diff = ChartInvalidation(from: configuration, to: configuration)
        #expect(!diff.restartsCandleSession)
        #expect(!diff.candleDimensionsChanged)
        #expect(!diff.geometryChanged)
        #expect(!diff.appearanceChanged)
        #expect(!diff.requiresRedraw)
    }

    @Test func sourceIdentityRestartsTheSession() throws {
        let diff = ChartInvalidation(
            from: try InvalidationFixture.configuration(sourceID: "offline"),
            to: try InvalidationFixture.configuration(sourceID: "binance")
        )
        #expect(diff.restartsCandleSession)
        #expect(!diff.geometryChanged)
        #expect(!diff.appearanceChanged)
        #expect(diff.requiresRedraw)
    }

    @Test func loadingCapabilityChangeRestartsTheSession() throws {
        let diff = ChartInvalidation(
            from: try InvalidationFixture.configuration(features: .all),
            to: try InvalidationFixture.configuration(features: [.gapRecovery])
        )
        #expect(diff.restartsCandleSession)
        #expect(diff.requiresRedraw)
    }

    @Test func contentChangeRebuildsGeometryWithoutRestarting() throws {
        let diff = ChartInvalidation(
            from: try InvalidationFixture.configuration(content: .candlestick),
            to: try InvalidationFixture.configuration(content: .timeSeries)
        )
        #expect(!diff.restartsCandleSession)
        #expect(diff.geometryChanged)
        #expect(!diff.appearanceChanged)
        #expect(diff.requiresRedraw)
    }

    @Test func layoutChangeRebuildsGeometryAndRedraws() throws {
        let diff = ChartInvalidation(
            from: try InvalidationFixture.configuration(),
            to: try InvalidationFixture.configuration(
                appearance: ChartAppearance(layoutMetrics: LayoutMetrics(mainChartHeight: 200))
            )
        )
        #expect(diff.geometryChanged)
        #expect(diff.appearanceChanged)
        #expect(!diff.candleDimensionsChanged)
        #expect(diff.requiresRedraw)
    }

    @Test func candleDimensionChangeReSeedsZoom() throws {
        let diff = ChartInvalidation(
            from: try InvalidationFixture.configuration(),
            to: try InvalidationFixture.configuration(
                appearance: ChartAppearance(candleStyle: CandleStyle(width: 6, gap: 1))
            )
        )
        #expect(diff.candleDimensionsChanged)
        #expect(diff.geometryChanged)
        #expect(diff.appearanceChanged)
        #expect(!diff.restartsCandleSession)
        #expect(diff.requiresRedraw)
    }

    @Test func colorOnlyChangeRedrawsWithoutTouchingGeometry() throws {
        let diff = ChartInvalidation(
            from: try InvalidationFixture.configuration(),
            to: try InvalidationFixture.configuration(appearance: ChartAppearance(watermarkText: nil))
        )
        #expect(diff.appearanceChanged)
        #expect(!diff.geometryChanged)
        #expect(!diff.candleDimensionsChanged)
        #expect(diff.requiresRedraw)
    }

    /// Guards the equivalence the view and coordinator rely on: geometry inputs never widen the
    /// historical redraw predicate because section heights and candle dimensions are part of appearance.
    @Test func redrawMatchesHistoricalPredicate() throws {
        let variants: [ChartConfiguration] = [
            try InvalidationFixture.configuration(),
            try InvalidationFixture.configuration(sourceID: "binance"),
            try InvalidationFixture.configuration(features: [.liveUpdates]),
            try InvalidationFixture.configuration(content: .timeSeries),
            try InvalidationFixture.configuration(
                appearance: ChartAppearance(layoutMetrics: LayoutMetrics(mainChartHeight: 200))
            ),
            try InvalidationFixture.configuration(
                appearance: ChartAppearance(candleStyle: CandleStyle(width: 6, gap: 1))
            ),
            try InvalidationFixture.configuration(appearance: ChartAppearance(watermarkText: nil))
        ]
        for old in variants {
            for new in variants {
                let diff = ChartInvalidation(from: old, to: new)
                let historical = diff.restartsCandleSession
                    || old.content != new.content
                    || !old.appearance.hasSameVisuals(as: new.appearance)
                #expect(diff.requiresRedraw == historical)
            }
        }
    }
}
#endif
