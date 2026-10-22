# 数据源接入

[English](../data-providers.md) | **简体中文**

[文档索引](README.md) · [配置](configuration.md) · [插件](plugins.md)

主 K 线时间轴使用 `ChartItemProvider`。成交记录等独立时间数据使用 `RangeDataProvider`。两者的请求、游标、完成状态和错误互不混用。

```text
Provider factory (runs once per primary session)
        │  history pages ──┐
        │  live stream ────┤→ merge → indicator batch → one consistent snapshot
        │  recovery fetch ─┘              │
        │                                 └→ visible-range rendering + plugin input
        └─ RangeLoader (independent cursor paging per plugin)
```

## K 线数值

`ChartItem` 描述不可变、可跨并发边界传递的 OHLCV 快照。可以直接使用 `Candle`，也可以实现自定义类型。

- `timestamp` 是开盘时刻的 Unix **秒**，不是毫秒；同一根 K 线的各次修订保持时间戳不变。
- `open`、`high`、`low`、`close` 为价格。输入必须有限且满足 `high >= low`；初始化器直接保存数值，不校验交易所规则。
- `volume` 和 `value` 使用数据源定义的基础资产与计价资产单位，在 `Candle` 中默认均为零。
- 历史数据可以乱序或重叠。同一批次内，相同时间戳或已配置时间桶保留最后出现的项；批次合并时，传入补丁覆盖已有匹配项。库不会比较交易所修订号或判断快照新旧。

不要用 K 线数组下标作为事件身份：前插历史数据会改变下标。

## 主数据源契约

`ChartItemProvider` 是要求 `Sendable` 的类协议。需要实现两个历史查询方法；`candlePeriod` 默认为 `nil`，`liveStream()` 默认立即结束。

| API | 契约 |
|---|---|
| `fetchChartItems(forPage:)` | 第 `0` 页最新，页码越大越早；空页结束分页 |
| `fetchChartItems(from:to:)` | 包含起止时刻的恢复区间 |
| `liveStream()` | 完整 K 线快照，可以修订已有 K 线 |
| `candlePeriod` | 匹配快照使用的可选固定 Unix 时间桶；`nil` 表示精确匹配时间戳 |

### 一个最小 provider

以下骨架把传输细节交给 `MarketClient` 协议；替换为你自己的网络层。示例应用中的 [`BinanceDataProvider`](../../SwiftKLineExample/BinanceDataProvider.swift) 是完整的 HTTP + WebSocket 实现。

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

要点：

- `candlePeriod` 是固定时间桶时长。日历周期（如交易所月线）返回 `nil`；精确的开盘时间戳才是那里唯一可靠的身份。
- `fetchChartItems(forPage:)` 用第 `0` 页表示最新历史；更大页码向过去回退。返回空页结束分页。
- `fetchChartItems(from:to:)` 接收包含起止的恢复区间。
- `liveStream()` 产出完整 K 线快照，包括对已发布 K 线的修订。增量成交量等差量消息先在 provider 中汇总。
- `onTermination` 取消生产任务。取消流的消费者不会自动清理独立创建的任务或 socket。

把 provider 接入配置时启用加载能力并挂接错误回调：

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

`CandleSource.id` 是语义身份，不是标签；见[数据源标识与更新](configuration.md#数据源标识与更新)。功能开关与错误回调见[加载能力](configuration.md#加载能力)与[错误处理](configuration.md#错误处理)。

## 历史分页

- 第 `0` 页是最新历史；图表滚近前缘时请求更早页。首个历史页与实时订阅并发启动。
- 抛错不消耗该页页码，下一次靠近左边缘的请求会重试失败页。主加载器没有公开 `retry()` API，也不会定时自动重试。
- 空页结束分页（第 `0` 页为空仍会建立基线）。
- 合并层接受重叠与重复数据，但仍应限制单页大小。
- 增量成交量等差量消息需要先在 provider 中汇总，再输出完整快照。

`SnapshotProvider` 覆盖静态图表：第零页返回捕获数组，后续页为空，不提供持续更新。替换快照时更换 `CandleSource.id`。

## 实时快照

`liveStream()` 产出完整 K 线快照；一行可以修订既有 K 线，加载器会把尾部追加与中间修订对齐到指标输出。

- 加载器合并实时消息；正在计算时，新消息进入下一批，即使有更新的 tick 在等待，一个有限批次也会完整发布。实时更新默认以 **200 ms** 窗口合并；历史与配置失效请求不经过该延迟。
- 实时流结束后，加载器不会立即循环重试。传输重连由 provider 负责；后续活跃或网络事件也可以启动新订阅。
- Provider 应支持取消后重新订阅。根据是否允许丢弃中间快照选择缓冲或聚合策略，并在 `onTermination` 中取消生产任务、关闭 socket。
- 首页历史到达之前收到的实时 tick 会被保留，并在基线发布后应用。

## 前台切换与缺口恢复

进入后台或非活跃场景会取消实时消费与恢复请求；在途的历史页继续。回到前台（或网络恢复时），若已知最后 K 线时间戳，会以该时间戳发起恢复查询。恢复先于重连执行，避免较早的 HTTP 快照覆盖更新的实时 tick。

恢复请求结束后——即使报错——会重新消费实时流。库不会自动拆分恢复区间，也不会感知 provider 内部的重连，因此不保证所有缺失 K 线都已恢复。具备网络意识的 provider（例如离线时跳过恢复）应在 `fetchChartItems(from:to:)` 中自行决策；图表只看到成功或失败。

恢复错误通过 `onLoadError` 报告。缺口恢复需要 `.gapRecovery` 能力，网络观察由库内部处理。

### 可运行的网络示例

示例应用中的完整 [`BinanceDataProvider`](../../SwiftKLineExample/BinanceDataProvider.swift) 是网络行情的参考实现。结合上面的契约阅读，可以看到：

- 带状态码校验和类型化解码的 HTTP 历史与恢复请求。
- 将交易所毫秒时间戳转换为库使用的 Unix 秒。
- 通过 WebSocket 订阅输出完整 K 线快照。
- 有界流缓冲，以及在 `onTermination` 中清理生产任务和 socket。
- 每次订阅使用独立传输客户端，使取消与重新订阅相互隔离。

该 provider 每次区间请求最多返回 1,000 条，历史页使用名义 `period.seconds` 时间窗口，月线也是如此。它有意只作为交易所传输示例，而不是完整的生产数据层。生产 provider 还需要按场景加入认证与限流策略、为较长恢复区间自行分页，并为月线历史采用真实日历边界。

## 时间与边界

每根真实存在的 K 线都有显式半开区间 `[open, end)`：

- 固定周期使用 `CandleSource(id:duration:provider:)`。
- 日历或交易时段边界使用 `CandleSource(id:candleInterval:provider:)`。
- `ChartPeriod.oneMonth.seconds` 仅是名义时长。月线 provider 应使用 `candlePeriod == nil`。

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

示例采用 UTC 公历月。实际应用应使用交易所定义的日历与时区，并确保数据源边界规则与 provider 的时间桶匹配方式一致。

不要把下一根已加载 K 线的时间当作当前 K 线结束时间，否则缺失 K 线会使事件归属错误。可见时间范围跨越可见 K 线，中间可能存在缺口。使用 `ChartContext.candleIndex(containing:)` 查找真实归属；不存在对应 K 线时可跳过事件。事件的 `Date` 可以保留亚秒精度。

## 独立范围分页

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

数据项由应用定义，无须遵循 `ChartItem`。游标仅对所属查询范围及其排序有效。

1. 每个缺失半开区间从 `cursor: nil` 开始。
2. 在同一区间内使用返回的游标继续请求。
3. `nextCursor == nil` 表示区间查询完成，包括空结果。
4. 空页带非 `nil` 游标时继续分页。
5. 失败页保持区间未完成，并保留游标供重试。

例如已覆盖 `[12:00, 13:00)`，新需求是 `[11:30, 12:30)` 时，只加载 `[11:30, 12:00)`。查询完成的空区间同样计入覆盖。

## RangeLoader 生命周期

`RangeLoader<Provider, ID>` 是 actor 工具，用于合并可见范围需求，每个会话维护一个活跃请求。初始化时传入 provider、数据项身份和时间提取闭包，以及 `onUpdate` 回调：

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

把可见范围与活跃状态转发给它（通常来自插件的 `context.input`），再把发布快照应用到渲染器：

| 方法 | 行为 |
|---|---|
| `load(in:)` | 替换最新需求范围，加载未覆盖部分 |
| `retry()` | 重试失败游标，保留已完成覆盖和缓存项 |
| `setActive(_:)` | 暂停或恢复请求，保留未完成进度 |
| `stop()` | 永久结束会话；再次加载需要新建 loader |

`RangeSnapshot` 包含按时间排序的缓存项、已完成区间、加载状态和错误。`onUpdate` 在每页成功或失败后于 `MainActor` 执行；仅开始、暂停或停止不会调用它。调用方需要命令执行后的即时状态时，可读取 `await loader.snapshot`。

更新需求通常会先让当前查询完成，再补齐最新需求中的缺失部分。失败后改变需求会丢弃失败查询的游标；重试未变需求则保留游标。已完成覆盖和缓存项会保留，直到被淘汰。

查询半开区间以外的数据项会被忽略。相同稳定 ID 的数据替换缓存值。同一时刻的不同数据项保持稳定顺序。已完成区间直接复用，不设时效超时或自动刷新。某次响应中缺少一项不等于删除；删除和独立实时更新需要应用自行定义协议。

## 缓存与失败行为

默认最多缓存 **20,000 项数据**和 **64 个已完成区间**。淘汰数据会使相关覆盖失效，重访时可重新加载。可见需求优先保留，但单页响应大小仍影响峰值内存。

| 失败 | 处理方式 |
|---|---|
| Provider 抛出错误 | 查看 `RangeSnapshot.error`，重试失败游标 |
| 重复游标 | `RangeLoadingError.repeatedCursor` 阻止无限查询 |
| 可见数据超出容量 | `cacheCapacityExceeded` 停止加载；提高容量、缩小范围或聚合数据 |

插件可用 `context.report(_:)` 转发错误，并在自身数据不可用时保留主图。账户或查询变化时，停止旧 loader、清空插件快照并创建新会话；除取消任务外，还要在异步回调中校验会话身份。完整接入过程见[插件指南](plugins.md#独立数据会话)，最终可参考[成交标记实现](../../SwiftKLineExample/TradeMarkers/TradeMarkers.swift)。
