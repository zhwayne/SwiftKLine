# Data providers and pagination

**English** | [简体中文](zh-CN/data-providers.md)

[Documentation](README.md) · [Configuration](configuration.md) · [Plugins](plugins.md)

Use `ChartItemProvider` for the primary candle timeline. Use `RangeDataProvider` for independent time-addressed data such as application events. Their requests, cursors, completion state, and errors are separate.

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

A thrown request does not consume its history page number. An older-page request is triggered near the leading edge of the chart; a subsequent loading trigger can retry a failed page. There is no public primary-loader `retry()` API or automatic timed history retry. Bound page size even though the merge layer accepts overlaps and duplicates. Aggregate deltas such as incremental volume inside the provider before yielding a complete snapshot.

On foreground activation or a network-available notification, an enabled recovery query starts from the last known candle timestamp when one exists. The loader cancels live consumption and waits for that recovery request before resubscribing. Recovery errors are reported through `onLoadError`, then live consumption resumes anyway. The library does not split the recovery interval into multiple requests, nor observe reconnects internal to a provider. It does not guarantee that every missing candle has been recovered.

The initial history page and live subscription start concurrently. If a live stream finishes, the loader does not immediately restart it in a retry loop; transport reconnection belongs to the provider, or a later activity/network event can start a fresh subscription. Providers must support subscriptions after cancellation.

### Working network example

The example app's complete [`BinanceDataProvider`](../SwiftKLineExample/BinanceDataProvider.swift) is the reference implementation for a network feed. Read it alongside the contract above; it demonstrates:

- HTTP history and recovery requests with status validation and typed decoding.
- Conversion from exchange millisecond timestamps to the library's Unix seconds.
- Complete live candle snapshots from a WebSocket subscription.
- A bounded stream buffer plus producer and socket cleanup in `onTermination`.
- A fresh transport client for every subscription so cancellation and resubscription stay isolated.

The provider returns at most 1,000 rows per interval request and uses nominal `period.seconds` windows for history pages, including monthly history. It is intentionally an exchange-transport example rather than a production data layer. Production providers need authentication and rate-limit policy where applicable, their own pagination for long recovery intervals, and calendar-aware boundaries for monthly history.

Choose stream buffering according to the feed's semantics. In `onTermination`, cancel producer tasks and close sockets owned by the subscription. Cancellation of the stream consumer does not clean up every independently created task.

For static charts, `SnapshotProvider` returns its captured array on page zero and an empty array on later pages. It does not stream updates. Replace it by changing `CandleSource.id`.

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

`RangeLoader<Provider, ID>` is an actor utility for merging visible requirements and managing one active request per session. Initialize it with a provider, item identity and time extractors, and an `onUpdate` callback.

`RangeSnapshot` contains time-sorted cached items, completed ranges, loading state, and an error. `onUpdate` runs on the `MainActor` after a page succeeds or fails; starting, pausing, or stopping alone does not invoke it. Read `await loader.snapshot` when the caller needs current state immediately after a command.

| Method | Behavior |
|---|---|
| `load(in:)` | Replaces the latest required range and loads missing coverage |
| `retry()` | Retries failed cursors while preserving completed coverage and cached items |
| `setActive(_:)` | Pauses or resumes requests while preserving partial progress |
| `stop()` | Ends the session permanently; create another loader to start again |

Updating demand normally lets the current query finish, then fills missing parts of the latest demand. Changing demand after a failure discards that failed query's cursor; retrying unchanged demand retains it. Completed coverage and cached items are retained subject to eviction.

Items outside the query's half-open interval are ignored. An item with the same stable ID replaces its cached value. Different items at the same time keep stable ordering. Completed ranges are reused without a freshness timeout or automatic refresh. Missing items in one response do not imply deletion; deletion and independent live changes need an application-defined protocol.

## Cache and failure behavior

Defaults are **20,000 cached items** and **64 completed ranges**. Eviction invalidates related coverage so revisiting that range can reload it. Visible demand has retention priority. Per-page response size still affects peak memory.

| Failure | Response |
|---|---|
| Provider throws | Inspect `RangeSnapshot.error`; retry the failed cursor |
| Repeated cursor | `RangeLoadingError.repeatedCursor` prevents an endless query |
| Visible data exceeds capacity | `cacheCapacityExceeded` stops loading; raise capacity, narrow demand, or aggregate data |

A plugin can forward errors with `context.report(_:)` and retain the primary chart while its own data is unavailable.

When an account or query changes, stop the old loader, clear the plugin's snapshot, and create a new session. Check session identity in asynchronous callbacks as well as cancelling tasks. A revoked chart context ignores resource mutations and redraw requests; application code must also prevent old results from modifying its own state. See the [trade-marker implementation](../SwiftKLineExample/TradeMarkers/TradeMarkers.swift) for a complete example.
