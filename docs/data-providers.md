# Data providers

**English** | [简体中文](zh-CN/data-providers.md)

[Documentation](README.md) · [Configuration](configuration.md) · [Plugins](plugins.md)

Use `ChartItemProvider` for the primary candle timeline. Use `RangeDataProvider` for independent time-addressed data such as application events. Their requests, cursors, completion state, and errors are separate.

```text
Provider factory (runs once per primary session)
        │  history pages ──┐
        │  live stream ────┤→ merge → indicator batch → one consistent snapshot
        │  recovery fetch ─┘              │
        │                                 └→ visible-range rendering + plugin input
        └─ RangeLoader (independent cursor paging per plugin)
```

## Candle values

`ChartItem` describes an immutable, `Sendable` OHLCV snapshot. Use `Candle` directly or supply your own conforming type.

- `timestamp` is the candle-open Unix time in **seconds**, not milliseconds. Keep it stable across revisions.
- `open`, `high`, `low`, and `close` are price values. Inputs must be finite and `high >= low`; the initializer stores values without validating exchange rules.
- `volume` and `value` use the provider's base and quote units; they default to zero in `Candle`.
- History can be unordered or overlapping. Within one batch, the last occurrence of a timestamp or configured bucket wins. When merging batches, the incoming patch replaces matching stored entries; the library does not compare exchange revision numbers or snapshot freshness.

Do not use a candle's array index as an event identity: prepending history changes indexes.

## Primary provider contract

`ChartItemProvider` is a `Sendable` class protocol. Implement both history methods; `candlePeriod` defaults to `nil`, and `liveStream()` defaults to an immediately finished stream.

| API | Contract |
|---|---|
| `fetchChartItems(forPage:)` | Page `0` is newest; larger indexes move backward. An empty page ends pagination |
| `fetchChartItems(from:to:)` | Inclusive recovery interval |
| `liveStream()` | Complete candle snapshots, including revisions of an existing candle |
| `candlePeriod` | Optional fixed Unix-time bucket used to match snapshots; `nil` matches exact timestamps |

### A minimal provider

This skeleton delegates transport details to a `MarketClient` protocol; replace it with your networking stack. The example app's [`BinanceDataProvider`](../SwiftKLineExample/BinanceDataProvider.swift) is a complete HTTP and WebSocket implementation.

```swift
import Foundation
import SwiftKLine

protocol MarketClient: Sendable {
    func history(symbol: String, period: ChartPeriod, page: Int) async throws -> [Candle]
    func history(symbol: String, period: ChartPeriod, from: Date, to: Date) async throws -> [Candle]
    func liveCandles(symbol: String, period: ChartPeriod) -> AsyncThrowingStream<Candle, Error>
}

final class MarketDataProvider: ChartItemProvider {
    private let symbol: String
    private let period: ChartPeriod
    private let client: any MarketClient

    init(symbol: String, period: ChartPeriod, client: any MarketClient) {
        self.symbol = symbol
        self.period = period
        self.client = client
    }

    var candlePeriod: ChartPeriod? {
        period == .oneMonth ? nil : period
    }

    func fetchChartItems(forPage page: Int) async throws -> [any ChartItem] {
        try await client.history(symbol: symbol, period: period, page: page)
    }

    func fetchChartItems(from start: Date, to end: Date) async throws -> [any ChartItem] {
        try await client.history(symbol: symbol, period: period, from: start, to: end)
    }

    func liveStream() -> AsyncStream<any ChartItem> {
        AsyncStream(bufferingPolicy: .bufferingNewest(256)) { continuation in
            let task = Task {
                do {
                    for try await candle in client.liveCandles(symbol: symbol, period: period) {
                        guard !Task.isCancelled else { break }
                        continuation.yield(candle)
                    }
                } catch {
                    // Log the transport error in the application.
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
```

The important parts:

- `candlePeriod` is a fixed bucket duration. Return `nil` for calendar periods such as exchange months; exact candle-open timestamps are the only reliable identity there.
- `fetchChartItems(forPage:)` uses page `0` for the newest history. Later pages move backward. Return an empty page to end pagination.
- `fetchChartItems(from:to:)` receives an inclusive recovery interval.
- `liveStream()` yields complete candle snapshots, including revisions of an already published candle. Aggregate deltas such as incremental volume before yielding.
- `onTermination` cancels the producer. Cancelling the stream consumer does not automatically clean up tasks or sockets created independently.

Wire the provider into a configuration with loading features and error callbacks:

```swift
@MainActor
func liveConfiguration(client: any MarketClient) throws -> ChartConfiguration {
    let source = CandleSource(id: "exchange:BTCUSDT:1m:UTC", duration: 60) {
        MarketDataProvider(symbol: "BTCUSDT", period: .oneMinute, client: client)
    }
    return try ChartConfiguration(
        source: source,
        features: [.liveUpdates, .gapRecovery]
    )
}
```

`CandleSource.id` is a semantic identity, not a label; see [source identity and updates](configuration.md#source-identity-and-updates). Feature switches and error callbacks live in [configuration](configuration.md#candle-loading-features) and [errors](configuration.md#errors).

## History pages

- Page `0` is the newest history; older pages load when the chart scrolls near the leading edge. The initial history page and the live subscription start concurrently.
- A thrown error does not consume its page number, so the next older-page request retries it. There is no public primary-loader `retry()` API and no automatic timed retry; scrolling near the missing edge triggers the next attempt.
- An empty page (other than an empty page `0`, which still establishes the baseline) ends pagination.
- The merge layer accepts overlaps and duplicates, but you should still bound page size.
- Aggregate deltas such as incremental volume inside the provider before yielding a complete snapshot.

`SnapshotProvider` covers static charts: it returns its captured array on page zero and an empty array on later pages, and it does not stream updates. Replace the snapshot by changing `CandleSource.id`.

## Live snapshots

`liveStream()` yields complete candle snapshots; a row may revise an existing candle, and the loader keeps tail appends and interior revisions aligned with indicator outputs.

- The loader merges incoming ticks; during calculation a tick waits for the next batch, and a finite batch publishes even while newer ticks wait. Live updates coalesce on a **200 ms** window by default; history and configuration invalidation requests bypass that delay.
- When the stream returns, the loader does not restart it in a retry loop. Transport reconnection belongs to the provider; a later activity or network event can also start a fresh subscription.
- Providers must support resubscription after cancellation. Choose buffer size or aggregation according to whether intermediate snapshots may be dropped, and release producer tasks and sockets in `onTermination`.
- Live ticks that arrive before the first history page are retained and applied after the baseline publishes.

## Background gaps and recovery

Entering the background or an inactive scene cancels live consumption and any recovery request; in-flight historical pages continue. On foreground return (or when the network becomes available), an enabled recovery query starts from the last known candle timestamp when one exists. Recovery runs before reconnection, so an older HTTP snapshot cannot overwrite newer live ticks.

After the recovery request completes — even on error — live consumption resumes. The library does not split the recovery interval into multiple requests, does not observe reconnects internal to a provider, and does not guarantee that every missing candle has been recovered. Providers with network-aware behavior (for example skipping recovery while the device is offline) should decide within `fetchChartItems(from:to:)`; the chart only sees success or failure.

Recovery errors are reported through `onLoadError`. Gap recovery requires the `.gapRecovery` feature and a network observer handled internally.

### Working network example

The example app's complete [`BinanceDataProvider`](../SwiftKLineExample/BinanceDataProvider.swift) is the reference implementation for a network feed. Read it alongside the contract above; it demonstrates:

- HTTP history and recovery requests with status validation and typed decoding.
- Conversion from exchange millisecond timestamps to the library's Unix seconds.
- Complete live candle snapshots from a WebSocket subscription.
- A bounded stream buffer plus producer and socket cleanup in `onTermination`.
- A fresh transport client for every subscription so cancellation and resubscription stay isolated.

The provider returns at most 1,000 rows per interval request and uses nominal `period.seconds` windows for history pages, including monthly history. It is intentionally an exchange-transport example rather than a production data layer. Production providers need authentication and rate-limit policy where applicable, their own pagination for long recovery intervals, and calendar-aware boundaries for monthly history.

## Time and boundaries

Every existing candle has an explicit half-open interval `[open, end)`:

- Use `CandleSource(id:duration:provider:)` for genuinely fixed periods.
- Use `CandleSource(id:candleInterval:provider:)` for real calendar or trading-session boundaries.
- `ChartPeriod.oneMonth.seconds` is a nominal duration. A calendar-month provider should use `candlePeriod == nil`.

```swift
import Foundation
import SwiftKLine

func monthlySource(id: String, provider: @escaping @Sendable () -> any ChartItemProvider) -> CandleSource {
    CandleSource(id: id, candleInterval: { timestamp in
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let open = Date(timeIntervalSince1970: Double(timestamp))
        return open..<calendar.date(byAdding: .month, value: 1, to: open)!
    }, provider: provider)
}
```

This example assumes Gregorian months in UTC. Use the exchange's actual calendar and time zone. Source boundary rules and provider bucket matching must agree.

Never infer a candle's end from the next loaded timestamp: missing candles would create false ownership of events. The visible time range spans visible candles and can include gaps. Use `ChartContext.candleIndex(containing:)` to find a real owning candle; skip an event if there is none. Event `Date` values can retain sub-second precision.

## Independent range pagination

```swift
public struct RangePage<Item: Sendable, Cursor: Hashable & Sendable>: Sendable {
    public let items: [Item]
    public let nextCursor: Cursor?

    public init(items: [Item], nextCursor: Cursor?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public protocol RangeDataProvider: Sendable {
    associatedtype Item: Sendable
    associatedtype Cursor: Hashable & Sendable

    func fetch(in range: Range<Date>, cursor: Cursor?) async throws -> RangePage<Item, Cursor>
}
```

Items are application-owned and need not conform to `ChartItem`. A cursor is valid only for its query range and ordering.

1. Start each missing half-open range with `cursor: nil`.
2. Continue with the returned cursor within that same range.
3. `nextCursor == nil` completes the range, including an empty result.
4. An empty page with a non-`nil` cursor continues pagination.
5. A failed page leaves the range incomplete and retains its cursor for retry.

When `[12:00, 13:00)` is covered and the next requirement is `[11:30, 12:30)`, only `[11:30, 12:00)` needs loading. Completed empty ranges count as covered.

## RangeLoader lifecycle

`RangeLoader<Provider, ID>` is an actor utility for merging visible requirements and managing one active request per session. Initialize it with a provider, item identity and time extractors, and an `onUpdate` callback:

```swift
let loader = RangeLoader(
    provider: tradeProvider,
    maxCachedItems: 20_000,
    identity: { $0.id },
    timestamp: { $0.timestamp }
) { snapshot in
    // Runs on the main actor after each page result.
}
```

Forward the visible range and active state to it (typically from a plugin's `context.input`), then apply the published snapshot to the renderer:

| Method | Behavior |
|---|---|
| `load(in:)` | Replaces the latest required range and loads missing coverage |
| `retry()` | Retries failed cursors while preserving completed coverage and cached items |
| `setActive(_:)` | Pauses or resumes requests while preserving partial progress |
| `stop()` | Ends the session permanently; create another loader to start again |

`RangeSnapshot` contains time-sorted cached items, completed ranges, loading state, and an error. `onUpdate` runs on the `MainActor` after a page succeeds or fails; starting, pausing, or stopping alone does not invoke it. Read `await loader.snapshot` when the caller needs current state immediately after a command.

Updating demand normally lets the current query finish, then fills missing parts of the latest demand. Changing demand after a failure discards that failed query's cursor; retrying unchanged demand retains it. Completed coverage and cached items are retained subject to eviction.

Items outside the query's half-open interval are ignored. An item with the same stable ID replaces its cached value. Different items at the same time keep stable ordering. Completed ranges are reused without a freshness timeout or automatic refresh. Missing items in one response do not imply deletion; deletion and independent live changes need an application-defined protocol.

## Cache and failure behavior

Defaults are **20,000 cached items** and **64 completed ranges**. Eviction invalidates related coverage so revisiting that range can reload it. Visible demand has retention priority, but per-page response size still affects peak memory.

| Failure | Response |
|---|---|
| Provider throws | Inspect `RangeSnapshot.error`; retry the failed cursor |
| Repeated cursor | `RangeLoadingError.repeatedCursor` prevents an endless query |
| Visible data exceeds capacity | `cacheCapacityExceeded` stops loading; raise capacity, narrow demand, or aggregate data |

A plugin can forward errors with `context.report(_:)` and retain the primary chart while its own data is unavailable. When an account or query changes, stop the old loader, clear the plugin's snapshot, and create a new session; check session identity in asynchronous callbacks as well as cancelling tasks. The complete walkthrough lives in the [plugin guide](plugins.md#independent-data-sessions), ending with the [trade-marker implementation](../SwiftKLineExample/TradeMarkers/TradeMarkers.swift).
