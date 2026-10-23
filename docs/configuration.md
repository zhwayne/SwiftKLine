# Configuration and integration

**English** | [简体中文](zh-CN/configuration.md)

[Documentation](README.md) · [Getting started](getting-started.md) · [Data providers](data-providers.md)

UIKit's `ChartView` and SwiftUI's `KLineChart` share one `ChartConfiguration`. Create and apply configurations on the main actor. This page is the reference for what a configuration contains and how the chart reacts to changes; the visual values themselves are covered in [appearance](appearance.md).

## Configuration fields

| Field | Purpose | Default |
|---|---|---|
| `source` | Provider factory, session semantic ID, and candle boundaries | Required |
| `appearance` | Theme, sizes, panels, legend, watermark, and indicator parameters | `ChartAppearance()` |
| `content` | Main-chart presentation | `.candlestick` |
| `plugins` | Ordered business features; IDs must be nonempty and unique | `[]` |
| `features` | Candle-loading capabilities | `.all` |

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
        features: []
    )
}
```

Validation happens at construction, before a running chart can be affected:

- `ChartConfigurationError.emptySourceID` — the source needs a nonempty semantic ID.
- `ChartConfigurationError.emptyPluginID` and `.duplicatePluginID(_:)` cover the plugin list.
- A fixed `duration` must be a finite positive number; this is a precondition, not a thrown error.

Changing the plugin list requires creating a new configuration so validation completes before the chart updates.

## Main-chart content

`content` chooses `.candlestick` or `.timeSeries` presentation, independent of indicator selection:

- `.timeSeries` hides main-panel plugins whose IDs resolve to built-in indicators, and candle high/low annotations. The latest-price label, price guide line, and return-to-latest control stay visible in both modes.
- Application `.main` plugins with their own IDs render in both modes.
- Hiding a built-in indicator does not remove its calculator; it stays selected and may keep calculating.

Changing only `content` re-presents the chart without restarting the provider.

## Source identity and updates

The `CandleSource.id` should identify the trading pair, period, venue, and calendar semantics, for example `exchange:BTCUSDT:1m:UTC`. The provider factory runs when a chart session starts. Rebuilding the closure under the same ID does not replace the existing provider — see the data provider guide for why.

A stable configuration passing through `chart.apply(_:)` (UIKit) or a props update (SwiftUI) reconciles instead of restarting:

| Change | Effect |
|---|---|
| Source ID and candle-loading features unchanged | Primary data session is kept |
| Source ID changed | Cancels old data and calculation tasks, clears primary data, rebuilds plugin coordinators |
| `.liveUpdates` or `.gapRecovery` changed | Rebuilds the primary session and plugin coordinators |
| Plugin ID and concrete type unchanged | Updates the existing coordinator |
| Plugins reordered | Keeps coordinator state; adjusts panel and draw order |
| Plugin removed or replaced by another type | Revokes context, then dismantles old resources |
| Appearance changed | Redraws; recalculates only series whose parameters changed |
| Only `content` changed | Switches presentation without restarting the provider |

Keep plugin IDs stable while their parameters change; the ID, not the parameter values, owns the coordinator. A plugin's account or query identity is its own responsibility, separate from the primary source identity.

Sharing one configuration value never shares runtime state: every chart instance owns its sessions, coordinators, and layers.

## Candle-loading features

| Capability | Effect |
|---|---|
| `.liveUpdates` | Consumes complete live candle snapshots |
| `.gapRecovery` | On foreground return or network availability, attempts interval recovery when a last timestamp is known |
| `.all` | Enables live updates and gap recovery |
| `[]` | Static charts and deterministic tests |

Pass a `ChartStateStore` to persist the complete `ChartSelection` (period and indicators); `nil` disables storage. SwiftKLine defines the protocol and provides UserDefaults and memory implementations. Storage keys are internal; `UserDefaultsChartStateStore(namespace:)` isolates charts. Applications can reuse the store for other preferences with typed keys. See [shared state storage](indicators.md#shared-state-store).

Chart activity follows window, scene, and application state: entering the background or an inactive scene cancels live consumption and recovery requests, while in-flight historical pages continue. Frontend return or network availability triggers recovery only when `.gapRecovery` is enabled and a last-known timestamp exists; live consumption resumes after the recovery attempt finishes, even if it reports an error.

## Errors

```swift
import UIKit
import SwiftKLine

func attach(chart: ChartView, configuration: ChartConfiguration) {
    chart.onLoadError = { error in
        // History page or gap recovery failed; the page index is not consumed.
    }
    chart.onPluginError = { pluginID, error in
        // One feature failed; other features keep running.
    }
    chart.apply(configuration)
}
```

- `onLoadError` reports history-page and recovery failures on the main actor. A failed page does not consume its page index, so the next older-page attempt retries it. The primary loader exposes no `retry()` API and does not auto-retry on a timer; scrolling near the left edge triggers the next attempt.
- `onPluginError` reports errors tagged with the failed plugin ID. A plugin's own data problems must not delay candles and indicators; the chart continues with the remaining features.
- The provider owns transport reconnection. The library never reconnects the live stream on its own.

## Chart API

`ChartView` (UIKit) and `KLineChart` (SwiftUI) expose the same operations through their platform idioms:

| Operation | UIKit | SwiftUI |
|---|---|---|
| Reconcile configuration | `apply(_:)` | Pass an updated `configuration` |
| Read selection state | `selection` | `selection` binding |
| Replace selection | `setSelection(_:)` | Set the bound value |
| Restore defaults | `resetSelectionToDefault()` | Set the desired default selection through the binding |
| Scroll to latest | `scrollToLatest()` | Not exposed on the adapter; the OS scroll-to-top gesture also targets the latest candle |
| Load errors | `onLoadError` | `onLoadError` initializer argument |
| Plugin errors | `onPluginError` | `onPluginError` initializer argument |
| Selection changed | `selectionChanged` | The binding receives user changes |
| State storage | `stateStore:` initializer argument | `stateStore:` initializer argument |

Applications own period and indicator controls, both backed by one `ChartSelection`. SwiftUI controls bind to `$selection.period` and `$selection.indicators`; UIKit uses `selection`, `setSelection(_:)`, and `selectionChanged`. With a selection-dependent configuration factory, the library restores and validates selection before constructing its source. Availability changes that adjust selection are also persisted and published. The static `configuration:` convenience is for manually managed sources without automatic period switching.

SwiftUI notes:

- Do not store a dynamic configuration in `@State` that is initialized once; models should hold the configuration and pass updated values down.
- Creating a chart starts its session; the adapter ends sessions when the view is removed.

## Common integration questions

| Symptom | Check |
|---|---|
| New snapshots don't show | Change the data-source ID; replacing only the factory closure keeps the old session |
| Indicator selection after launch is unexpected | Check the stored complete selection, supplied initial value, and available options |
| Period or symbol switch leaves stale data | Include period or symbol in the factory's `CandleSource.id`; the same ID retains its session |
| Events map to the wrong candle | Use Unix seconds and actual candle boundaries; see [time rules](data-providers.md#time-and-boundaries) |
| Chart height is unexpected | Check sub panels and parent constraints; application controls are outside the chart |
| Custom types fail to import | Trade-marker types are example code; implement them in your app or copy them |
