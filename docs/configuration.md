# Configuration and integration

**English** | [简体中文](zh-CN/configuration.md)

[Documentation](README.md) · [Quick start](../README.md#quick-start)

UIKit's `ChartView` and SwiftUI's `KLineChart` consume the same `ChartConfiguration`. Create and apply it on the `MainActor`.

## Configuration fields

| Field | Purpose | Default |
|---|---|---|
| `source` | Provider factory, semantic session ID, and candle boundaries | Required |
| `appearance` | Theme, dimensions, panels, legends, and indicator parameters | `ChartAppearance()` |
| `content` | Main chart presentation | `.candlestick` |
| `plugins` | Ordered application features with unique, non-empty IDs | `[]` |
| `indicators` | Initial built-in selector state | Appearance defaults, subject to persistence |
| `features` | Loading and selection-storage capabilities | `.all` |

`ChartConfiguration` throws `emptySourceID`, `emptyPluginID`, or `duplicatePluginID(_:)` from `ChartConfigurationError`. Changing the plugin list requires constructing a new configuration so validation runs before a chart is updated. A fixed source duration must be finite and positive; this is a precondition, not a thrown configuration error.

## Static and network sources

```swift
import SwiftKLine

@MainActor
func snapshotConfiguration(candles: [Candle], sourceID: String) throws -> ChartConfiguration {
    try ChartConfiguration(
        source: CandleSource(id: sourceID, duration: 60) {
            SnapshotProvider(items: candles)
        },
        appearance: .themed(.solaris),
        content: .candlestick,
        indicators: IndicatorSelectionState(
            mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol, .macd]
        ),
        features: []
    )
}
```

`SnapshotProvider` captures a finite array. Change the source ID to replace that snapshot. For continuous data, return your `ChartItemProvider` implementation from the factory; see [Data providers](data-providers.md).

## Identity and updates

Choose a source ID that identifies the symbol, period, venue, and calendar semantics, for example `exchange:BTCUSDT:1m:UTC`. A factory is invoked when a session starts; recreating a closure with the same source ID does not replace the existing provider.

| Change | Effect |
|---|---|
| Same source ID and loading flags | Retains the primary provider session |
| New source ID | Cancels old data and calculation work, clears primary data, and rebuilds plugin coordinators |
| Changed `.liveUpdates` or `.gapRecovery` | Rebuilds the primary session and plugin coordinators |
| Same plugin ID and concrete type | Updates the existing coordinator |
| Reordered plugins | Retains coordinator state; changes panel and drawing order |
| Removed plugin or changed concrete type | Revokes context and cleans up old resources |
| Changed appearance | Updates rendering; changed calculation parameters invalidate affected outputs |
| Changed content mode only | Changes presentation without restarting the provider |

Keep a plugin ID stable when its parameters change. A plugin's account or query identity is managed by that plugin separately from the primary source. Use an application-specific ID prefix; `builtin.` is reserved for built-in indicators. A declared plugin with a built-in ID replaces the selector-generated plugin with that exact ID, and recognized built-in IDs are hidden from the main panel in time-series mode.

Use `chart.apply(configuration)` in UIKit. In SwiftUI, pass the updated configuration to `KLineChart`; keep parent-provided dynamic input out of once-initialized `@State`. Each chart creates its own sessions even when charts receive the same configuration value.

## Indicators and selection

The selector offers MA, EMA, WMA, BOLL, SAR, BBI, VWMA, Donchian, SuperTrend (SUPER), Ichimoku (ICHI), VOL, RSI, MACD, KDJ, CCI, WR, DMI, ATR, OBV, ROC, MFI, and TRIX. Configure available entries with `ChartAppearance.indicators`, defaults and reset values with `defaultMainIndicators` / `defaultSubIndicators`, and parameters with `indicatorKeyOverrides`.

The initial selection uses the first applicable source below, then removes invalid, duplicate, unavailable, and incorrectly placed IDs:

| Priority | Source | When it applies |
|---|---|---|
| 1 | Persisted selection | Persistence is enabled and the stored selection is non-empty |
| 2 | `configuration.indicators` | An explicit selection is provided |
| 3 | Appearance defaults | Neither source above supplies a selection |

If normalization empties a persisted selection, the chart keeps that empty result instead of falling through to configuration or appearance defaults. The selector controls built-in indicators; application features are declared in `plugins`.

Later updates follow these rules:

| Update | Result |
|---|---|
| `configuration.indicators` changes to a value | Replaces the current selection |
| `configuration.indicators` changes to `nil` | Restores the current appearance defaults |
| The value is unchanged | Retains user selection, including across source changes |
| Appearance defaults change by themselves | Does not reset the current selection |

Use `setIndicators(_:)` or `resetIndicatorsToDefault()` for explicit commands.

Persistence loads at chart creation and saves after initial normalization and selector/set/reset commands. Applying configuration alone does not save the resulting selection. Enabling persistence on an existing chart does not reload storage. The default `UserDefaultsIndicatorSelectionStore` uses one shared key across sources and charts; inject a store with a different key in UIKit for isolation. `KLineChart` does not expose store injection; use a selection binding and disable built-in persistence when the app owns storage.

UIKit exposes `indicatorSelection`, `setIndicators(_:)`, and `resetIndicatorsToDefault()`. SwiftUI can bind selection:

```swift
import SwiftUI
import SwiftKLine

@MainActor
struct SelectionChart: View {
    let configuration: ChartConfiguration
    @State private var indicators = IndicatorSelectionState(
        mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol, .macd]
    )

    var body: some View {
        KLineChart(configuration: configuration, indicators: $indicators)
            .fixedSize(horizontal: false, vertical: true)
    }
}
```

When supplied, the binding takes priority on each SwiftUI update. The adapter synchronizes it into UIKit and reports subsequent user selections back without writing SwiftUI state during synchronization. IDs filtered out by UIKit are not automatically written back during that synchronization. Selector changes retain the primary provider and application plugin coordinators whose identities remain unchanged.

### Additional lower-panel indicators

Each selected indicator has one panel; multiple parameter keys for the same indicator share that panel. The existing example selection remains VOL and MACD.

| Indicator | Default and output | First available index / behavior |
|---|---|---|
| KDJ | (9, 3, 3), K/D/J | period − 1; K/D seeded at 50; recursive weights 1/kPeriod and 1/dPeriod; J = 3K − 2D |
| CCI | 20, typical-price CCI | period − 1; (H+L+C)/3, constant 0.015, exact mean absolute deviation |
| WR | 14, Williams %R | period − 1; international −100...0 scale |
| DMI | (14, 14), +DI/−DI/ADX | DI at diPeriod; ADX at diPeriod + adxPeriod − 1; Wilder smoothing; no ADXR |
| ATR | 14, Wilder RMA of true range | period − 1; first candle TR = H−L, complete-window mean seed |
| OBV | no period, cumulative signed volume | 0; starts at 0, unchanged close leaves OBV unchanged |
| ROC | 9, percentage close change | period; 100 × (close / historicalClose − 1), no signal line |
| MFI | 14, typical-price money flow | period; typical-price direction classifies volume-weighted flows |
| TRIX | 18, percentage change of triple EMA | 3 × (period − 1) + 1; every EMA uses a complete SMA seed; no signal line |

Indexes are zero-based. Outputs are input-aligned and nil during warm-up; DMI publishes its DI pair while ADX is still nil. Nonpositive periods return aligned nil outputs. CCI returns 0 for zero mean deviation. Flat KDJ windows use RSV 50, flat WR windows yield nil, and zero ROC/TRIX denominators yield nil. DMI tied directional moves, zero TR, and zero DI sum contribute 0. MFI with only positive flow is 100, only negative flow is 0, and neither flow is nil. These definitions fix this library's initialization; they do not promise identical values across platforms or different history start points.

Reference levels are KDJ/MFI 20 and 80, WR −80 and −20, CCI −100/0/100, DMI 20/25, and ROC/TRIX 0. KDJ bounds include J outside 0...100. ATR includes zero in its bounds; OBV scales to visible values. Missing/non-finite samples break paths; legends follow the selected or last visible candle.

Use the full key for both parameters and colors. Scalar indicators use `LineStyle`; compound outputs use public `KDJStyle` and `DMIStyle`. Custom keys fall back to readable line colors when no style matches. An explicit style map replaces defaults:

```swift
import UIKit
import SwiftKLine

let kdjKey = SeriesKey.kdj(period: 9, kPeriod: 3, dPeriod: 3)
let dmiKey = SeriesKey.dmi(diPeriod: 14, adxPeriod: 14)
let appearance = ChartAppearance(
    indicatorStyleRegistry: [
        kdjKey: KDJStyle(kColor: .systemOrange, dColor: .systemBlue, jColor: .systemPurple),
        dmiKey: DMIStyle(plusDIColor: .systemGreen, minusDIColor: .systemRed, adxColor: .systemOrange),
        .wr(period: 14): LineStyle(strokeColor: .systemBlue),
        .wr(period: 7): LineStyle(strokeColor: .systemPurple)
    ],
    indicatorKeyOverrides: [
        .kdj: [kdjKey],
        .dmi: [dmiKey],
        .wr: [.wr(period: 14), .wr(period: 7)]
    ]
)
let selection = IndicatorSelectionState(subIndicatorIDs: [.kdj, .dmi, .wr])
```

Core-only clients can instantiate `KDJCalculator`, `CCICalculator`, `WRCalculator`, `DMICalculator`, `ATRCalculator`, `OBVCalculator`, `ROCCalculator`, `MFICalculator`, and `TRIXCalculator` directly. KDJ returns `KDJIndicatorValue`, DMI returns `DMIIndicatorValue` with optional ADX, and the others return Double values. Updates use full recalculation.

Formula references: [KDJ](https://support.futunn.com/topic149), [CCI](https://www.tradingview.com/support/solutions/43000502001-commodity-channel-index-cci/), [DMI](https://www.tradingview.com/support/solutions/43000502250-directional-movement-dmi/), [ATR](https://www.tradingview.com/support/solutions/43000501823-average-true-range-atr/), [OBV](https://www.tradingview.com/support/solutions/43000502593-on-balance-volume-obv/), [MFI](https://www.tradingview.com/support/solutions/43000502348-money-flow-mfi/), and [TRIX](https://www.tradingview.com/support/solutions/43000502331-trix/).

## Appearance and layout

Use `.themed(.solaris)` for a light preset or `.themed(.midnight)` for a dark preset. Construct `ChartAppearance` directly to set candle styling, layout, legend fonts, and watermark text.

Indicator styles are keyed by the complete `SeriesKey`, including parameters. Supplying an explicit style dictionary replaces the defaults. `LineIndicatorRenderer` uses the label color if a matching `LineStyle` is absent.

The chart's intrinsic height includes the main panel, time axis, sub-panels, and selector. Provide horizontal constraints in UIKit. In SwiftUI, `.fixedSize(horizontal: false, vertical: true)` allows the intrinsic vertical size.

`.timeSeries` hides main-panel plugins with recognized built-in IDs and candle high/low annotations. The latest-price label, guide line, and return-to-latest control remain available in both modes. The area beneath the time-series line fades vertically to transparent. Custom `.main` plugins using application-specific IDs draw in both content modes. Hidden built-in indicators remain selected and can still calculate.

## Loading and errors

| Capability | Effect |
|---|---|
| `.liveUpdates` | Consumes complete live candle snapshots |
| `.gapRecovery` | Attempts interval recovery on foreground or network resumption when a last timestamp is known |
| `.indicatorPersistence` | Reads and writes built-in selector state |
| `.all` | Enables all three capabilities |

Use `[]` for static charts or deterministic tests. When persistence is disabled, selector storage is neither read nor written. With persistence enabled, UIKit clients can inject an `IndicatorSelectionStore` into `ChartView`.

Use `onLoadError` for history and recovery errors and `onPluginError` for errors tagged with a plugin ID. Both callbacks are available on `ChartView` and in the `KLineChart` initializer. Providers own live transport and reconnection behavior.

Window, scene, and app activity determine chart activity. Initialization starts the initial history request and, when enabled, live consumption. Becoming inactive cancels live consumption and recovery; it does not cancel an in-flight history page. Foreground activation or network availability can trigger recovery when enabled and a last timestamp is known. Live consumption resumes after the recovery attempt, including after an error. Application plugins receive `context.input.isActive` and manage their own requests and cancellation.

## Common integration problems

| Symptom | Check |
|---|---|
| New snapshot is not shown | Change the source ID; a new factory closure alone retains the old session |
| Wrong indicator selection after launch | Check persisted selection, appearance defaults, and any SwiftUI binding |
| Events map to the wrong candle | Use Unix seconds and actual candle boundaries; see [time rules](data-providers.md#time-and-boundaries) |
| Chart has an unexpected height | Check enabled sub-panels, selector, and parent constraints |
| Custom type cannot be imported | Trade-marker types belong to the example; implement or include them in your app |
