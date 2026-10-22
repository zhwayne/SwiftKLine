# Architecture and ownership

**English** | [简体中文](zh-CN/architecture.md)

[Documentation](README.md) · [Configuration](configuration.md) · [Plugins](plugins.md)

SwiftKLine separates candle data, indicator calculation, and visible-range drawing. One configuration describes a chart; each chart owns the runtime state needed to realize it.

## Module boundaries

```mermaid
flowchart TD
    Entry[SwiftKLine] --> Core[SwiftKLineCore]
    Entry --> UI[SwiftKLineUI]
    Entry --> Adapter[SwiftKLineSwiftUI]
    Adapter --> UI
    Adapter --> Core
    UI --> Core
```

| Module | Responsibility |
|---|---|
| `SwiftKLineCore` | Foundation models, merge rules, calculators, typed outputs, and range loaders |
| `SwiftKLineUI` | Configuration reconciliation, plugins, panels, layout, UIKit, and Core Animation |
| `SwiftKLineSwiftUI` | Configuration forwarding, binding synchronization, sizing, and teardown |
| `SwiftKLine` | Umbrella imports for package consumers |

Only `SwiftKLine` and `SwiftKLineCore` are library products. The umbrella's UI dependencies are conditional on iOS. Core has no UIKit dependency and supports host tests and benchmarks on macOS.

Exchange protocols, authentication, accounts, and execution semantics belong to the application. The library supplies the calculation, loading, and rendering contracts. The [trade-marker example](../SwiftKLineExample/TradeMarkers/TradeMarkerExample.swift) demonstrates that boundary.

## Ownership

| Owner | State |
|---|---|
| Application | Configuration values, provider implementation, business models, and account identity |
| Chart | Primary session, calculation publication, plugin coordinators, and drawing layers |
| Plugin coordinator | Feature-specific resources, independent sessions, subscriptions, and cancellation |
| SwiftUI adapter | Binding synchronization; it does not create a second data runtime |

A provider factory runs for each chart's new primary session. Sharing a configuration does not share a coordinator. If a factory returns a shared service, that service must isolate subscriptions and cancellation itself.

Plugins are matched by stable ID and concrete type. On removal or replacement, the host revokes the context before cleanup. Resource collections, panel assembly, type erasure, and internal session tokens stay inside the implementation.

## Data publication

```mermaid
flowchart LR
    Provider[Candle provider] --> Merge[Raw candles and merging]
    Merge --> Engine[IndicatorEngine]
    Engine --> Snapshot[Consistent candle and indicator snapshot]
    Snapshot --> Draw[Visible-range rendering]
    Snapshot --> Plugin[Plugin input]
    Plugin --> Range[Independent range loader]
    Range --> External[External snapshot]
    External --> Draw
```

The primary loader fetches history, consumes live snapshots, and recovers gaps. `IndicatorEngine` computes against an immutable candle batch. Candles and the indicator outputs calculated from them are published together, avoiding mixed revisions during rendering.

Live ticks arriving during calculation enter the next batch. History and configuration invalidation receive immediate scheduling priority. Source or calculation-semantic changes invalidate results from the old session.

Each plugin has an output namespace. Its renderer reads scoped series through `ChartContext`, so multiple plugins can use the same `SeriesKey` independently.

External range loaders do not join the primary publication barrier. Slow or failed application data does not delay candles and indicators; a completed external snapshot updates its renderer and requests a redraw.

## Concurrency and teardown

| Boundary | Work |
|---|---|
| `MainActor` | Configuration, plugin lifecycle, publication, views, and layers |
| Primary loader actor | History, live consumption, recovery, and request state |
| Each `RangeLoader` actor | Independent cursor, coverage, cache, and cancellation state |
| Structured calculation tasks | Indicator computation over immutable input |

Cross-boundary values are `Sendable`. Providers should cooperate with cancellation and close stream resources on termination. Session checks reject late results from requests that finish after cancellation.

Teardown cancels sessions, revokes contexts, dismantles plugin resources, and releases installed layers. Plugin-owned tasks still require explicit cleanup. See [plugin lifecycle](plugins.md#plugin-lifecycle).

## Rendering and interaction

The canvas remains viewport-sized. Total history width affects scrolling without creating a view for each candle. Renderers reuse layers and process visible data.

The main panel supports candlestick and time-series presentation. Time-series presentation hides main-panel plugins whose IDs resolve to built-in indicators and candle high/low annotations, while preserving the latest-price label, guide line, and return-to-latest control. Application `.main` plugins with their own IDs render in both modes. Hiding an indicator does not remove its calculator. Each plugin's `.sub` renderers share one sub-panel.

Scroll, zoom, and data updates redraw visible content. Crosshair updates can target interaction layers and legends. Data, configuration, and explicit plugin requests invalidate the legend cache; time-series paths also track interior candle revisions.

Events are mapped through actual candle intervals. Missing buckets must stay gaps; calendar and session rules are covered in [Time and boundaries](data-providers.md#time-and-boundaries). Cost and measurement guidance is in [Performance](performance.md).
