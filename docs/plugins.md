# Plugins and custom charts

**English** | [简体中文](zh-CN/plugins.md)

[Documentation](README.md) · [Configuration](configuration.md) · [Appearance](appearance.md) · [Data providers](data-providers.md)

Declare application features in `ChartConfiguration.plugins`. Each entry can own calculations, rendering, and an independent data source. Stable IDs identify features; declaration order determines plugin panel order. Prefix custom IDs with an application-specific name; the `builtin.` namespace is reserved. Selected built-in plugins are prepended to application plugins, except where an exact declared ID overrides one.

## Plugin lifecycle

```swift
@MainActor
public protocol ChartPlugin {
    associatedtype Coordinator = Void

    var id: String { get }
    func makeCoordinator() -> Coordinator
    func update(coordinator: Coordinator, context: ChartPluginContext)
    static func dismantleCoordinator(_ coordinator: Coordinator)
}
```

A plugin value describes configuration. A nested `Coordinator` holds per-chart mutable state such as renderers, loaders, and tasks. Stateless plugins can use `Void` and the default creation and cleanup implementations.

The host creates a coordinator and calls `update`. Later calls reflect configuration, published candles, viewport demand, or chart activity. Compare relevant inputs before replacing resources; `update` runs on the main actor and must not block it.

The same ID and concrete type retain a coordinator, including when plugins are reordered. Removal, replacement by a different type, or a primary session rebuild ends the old lifecycle. The host relinquishes entry ownership and revokes context access before dismantling. Cleanup may close the chart reentrantly without dismantling the same coordinator twice; an interrupted reconciliation disposes unpublished entries instead of installing them. Cancel tasks and subscriptions in `dismantleCoordinator(_:)`. Each chart needs independent coordinators, renderers, and layers.

## Add a calculated line

This plugin registers an MA calculator and generic line renderer only when its period changes:

```swift
import SwiftKLine

@MainActor
struct TrendLine: ChartPlugin {
    let id: String
    let period: Int

    @MainActor
    final class Coordinator {
        var period: Int?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func update(coordinator: Coordinator, context: ChartPluginContext) {
        guard coordinator.period != period else { return }
        coordinator.period = period
        let key = SeriesKey.ma(period: period)
        context.setCalculator(MACalculator(period: period), for: "average")
        context.setRenderer(LineIndicatorRenderer(series: [key]), for: "line", panel: .main)
    }
}

@MainActor
func trendConfiguration(source: CandleSource) throws -> ChartConfiguration {
    try ChartConfiguration(source: source, plugins: [
        TrendLine(id: "trend.fast", period: 20),
        TrendLine(id: "trend.slow", period: 60)
    ])
}
```

Keep `id` stable when changing `period`. `SeriesKey` includes the calculation parameters. Renderers access typed results through `ChartContext.values(for:as:)` or `visibleValues(for:as:)`. Style lookup also uses the complete key; see [indicator styles](appearance.md#indicator-styles).

## Inputs and resource registration

`context.input` contains the primary source ID, published candles, data revision, visible half-open time range, and active state. Scrolling changes the range without necessarily changing the data revision. Before layout is ready, the time range can be `nil`.

| Context API | Purpose |
|---|---|
| `setCalculator(_:for:)` | Registers or replaces a local calculator and invalidates outputs |
| `removeCalculator(for:)` | Removes a calculator and its outputs |
| `setRenderer(_:for:panel:)` | Registers or replaces a renderer in a panel |
| `removeRenderer(for:)` | Removes a local drawing resource |
| `requestRedraw()` | Invalidates drawing and legend without restarting calculations or data |
| `report(_:)` | Sends an error tagged with this plugin's ID |

Resource names are local to a plugin. Outputs are namespaced by plugin identity and `SeriesKey`; different plugins may calculate the same key. Two calculators within one plugin producing the same key report `ChartPluginError.duplicateSeries`.

Re-registering a calculator invalidates its output even if the key is unchanged. Renderer replacement uses object identity, so a new object is installed even if its renderer ID matches. After directly changing renderer state, call `requestRedraw()`.

## Panels and coordinate mapping

- `.main` draws in the primary price panel.
- All `.sub` renderers of one plugin share an independent sub-panel.
- Plugin declaration order determines sub-panel order.
- `zIndex` orders renderers within a group; equal priorities preserve declaration order.

A custom `ChartRenderer` installs reusable layers in `install(to:)`, updates them in `draw(in:context:)`, and removes them in `uninstall(from:)`. Optional `legend(context:)` supplies a legend; `dataBounds(context:)` supplies the visible domain. Return `.empty` to avoid extending axis bounds.

`ChartContext.visibleRange` uses absolute candle indexes. `layout.xPosition(at:)` takes an offset from that range's lower bound and returns the candle's left edge; add half the candle width for its center. Use `layout.yPosition(for:viewPort:)` for prices.

Read the drawing context during the current draw or legend call. Clip layers to `viewPort`; avoid network requests, sorting, or expensive object creation inside drawing callbacks.

## Independent data sessions

For data unrelated to candle calculations:

1. Create the provider, `RangeLoader`, and renderer in coordinator-owned state.
2. Forward `visibleTimeRange` and `isActive` through ordered loader commands.
3. Apply published snapshots to the renderer and request a redraw.
4. On an account or query change, stop the loader, clear local data, and reject late callbacks using a session identity.
5. On dismantling, cancel command tasks and loading work and release the context.

External data does not join the primary indicator calculation barrier. Its errors and retries should affect its own feature while the candle chart remains available. See [range pagination](data-providers.md#independent-range-pagination) for cursors, coverage, and cache behavior.

## Trade-marker example

The example app implements trade markers using application-owned models and services:

| Source | Responsibility |
|---|---|
| [TradeMarker.swift](../SwiftKLineExample/TradeMarkers/TradeMarker.swift) | Stable ID, date, price, and direction |
| [TradeMarkers.swift](../SwiftKLineExample/TradeMarkers/TradeMarkers.swift) | Marker style, coordination, cancellation, retry, and triangle renderer |
| [TradeMarkerExample.swift](../SwiftKLineExample/TradeMarkers/TradeMarkerExample.swift) | Providers and configuration composition |
| [TradeMarkerTests.swift](../SwiftKLineExample/TradeMarkers/Tests/TradeMarkerTests.swift) | Pagination, isolation, boundaries, and clipping tests |

These types are not exported by `SwiftKLine`. The following code belongs in the app module that includes the example types:

```swift
import SwiftKLine

@MainActor
func executionConfiguration(candles: [Candle], trades: [TradeMarker]) throws -> ChartConfiguration {
    try ChartConfiguration(
        source: CandleSource(id: "BTCUSDT:1m", duration: 60) {
            SnapshotProvider(items: candles)
        },
        plugins: [
            TradeMarkers(id: "account.trades", sourceID: "account-42:BTCUSDT", provider: {
                SnapshotTradeProvider(trades: trades)
            })
        ],
        features: []
    )
}
```

`SnapshotTradeProvider` uses finite pagination. `DemoTradeProvider` generates simulated events from an independent market query; real executions should come from the app's account service.

This finite snapshot example disables live updates and recovery with `features: []`. Changing only the provider closure retains the range session: update the example plugin's `sourceID` when replacing its trade snapshot, and change `retryID` to retry without clearing its cache. Changing `maxCachedItems` also rebuilds that plugin's range session.

The renderer uses green upward buy triangles and red downward sell triangles, 8 pt by default. Multiple events can map to one real candle. Its default style does not expand the price axis; execution-price bounds are an application choice. The default example page does not enable this plugin.
