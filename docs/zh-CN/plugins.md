# 插件与自定义图表

[English](../plugins.md) | **简体中文**

[文档索引](README.md) · [配置](configuration.md) · [数据源](data-providers.md)

在 `ChartConfiguration.plugins` 中声明业务功能。每项可拥有计算、绘制与独立数据源。稳定 ID 标识功能，声明顺序决定插件面板顺序。自定义 ID 使用应用专属前缀，`builtin.` 命名空间为内置指标保留。选中的内置插件会添加到业务插件之前；与显式声明 ID 完全相同时，由显式声明覆盖。

## 插件生命周期

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

插件值描述配置，嵌套 `Coordinator` 保存每个图表独有的可变状态，例如渲染器、loader 和任务。无状态插件可使用 `Void` 以及默认的创建、清理实现。

宿主创建协调器后调用 `update`。之后的调用反映配置、已发布 K 线、可见范围需求或活跃状态变化。替换资源前比较相关输入；`update` 在主 actor 上执行，不能阻塞。

相同 ID 和具体类型保留协调器，重排也不丢失状态。移除、替换为其他类型或主会话重建会结束旧生命周期。宿主先撤销上下文权限，再清理资源。请在 `dismantleCoordinator(_:)` 取消任务和订阅。每个图表需要独立的协调器、渲染器和图层。

## 添加计算曲线

以下插件只在周期变化时注册 MA 计算器和通用曲线渲染器：

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

改变 `period` 时保持 `id` 稳定。`SeriesKey` 包含计算参数。渲染器通过 `ChartContext.values(for:as:)` 或 `visibleValues(for:as:)` 读取类型匹配的结果。样式也使用完整 key 查找，详见[外观](configuration.md#外观与布局)。

## 输入与资源注册

`context.input` 包含主数据源 ID、已发布 K 线、数据修订号、可见半开时间范围与活跃状态。滚动会改变范围，但不一定改变修订号。布局就绪前，时间范围可以是 `nil`。

| 上下文 API | 用途 |
|---|---|
| `setCalculator(_:for:)` | 注册或替换局部计算器，并使输出失效 |
| `removeCalculator(for:)` | 移除计算器与对应输出 |
| `setRenderer(_:for:panel:)` | 在面板中注册或替换渲染器 |
| `removeRenderer(for:)` | 移除局部绘制资源 |
| `requestRedraw()` | 使绘制和图例失效，不重启计算或数据源 |
| `report(_:)` | 发送带本插件 ID 的错误 |

资源名称作用域限于当前插件。输出按插件身份和 `SeriesKey` 隔离；不同插件可以计算相同 key。同一插件中两个计算器输出同一 key 会报告 `ChartPluginError.duplicateSeries`。

重新注册计算器会使输出失效，即使 key 没有变化。渲染器替换依据对象身份，新对象不会因渲染器 ID 相同而被忽略。直接修改渲染器状态后调用 `requestRedraw()`。

## 面板与坐标映射

- `.main` 在主价格面板绘制。
- 同一插件的所有 `.sub` 渲染器共用独立副图。
- 插件声明顺序决定副图顺序。
- `zIndex` 控制组内顺序；优先级相同时保留声明顺序。

自定义 `ChartRenderer` 在 `install(to:)` 安装可复用图层，在 `draw(in:context:)` 更新，在 `uninstall(from:)` 移除。可选的 `legend(context:)` 提供图例；`dataBounds(context:)` 提供可见值域。返回 `.empty` 可避免扩展坐标轴范围。

`ChartContext.visibleRange` 使用绝对 K 线下标。`layout.xPosition(at:)` 接受相对该范围下界的偏移，返回蜡烛左边缘；加半个蜡烛宽度得到中心。价格使用 `layout.yPosition(for:viewPort:)` 转换。

仅在当前绘制或图例调用中读取绘制上下文。图层应裁剪到 `viewPort`；不要在绘制回调中请求网络、排序或创建昂贵对象。

## 独立数据会话

对于不依赖 K 线计算的数据：

1. 在协调器持有的状态中创建 provider、`RangeLoader` 和渲染器。
2. 通过有序的 loader 命令转发 `visibleTimeRange` 和 `isActive`。
3. 将发布快照应用到渲染器，并请求重绘。
4. 账户或查询变化时停止 loader、清空数据，并通过会话身份拒绝迟到回调。
5. 清理时取消命令任务和加载任务，释放上下文。

外部数据不加入主指标计算的完成屏障。它的错误和重试应仅影响自身功能，保持 K 线图可用。游标、覆盖与缓存行为见[范围分页](data-providers.md#独立范围分页)。

## 成交标记示例

示例应用通过自有模型和服务实现成交标记：

| 源码 | 职责 |
|---|---|
| [TradeMarker.swift](../../SwiftKLineExample/TradeMarkers/TradeMarker.swift) | 稳定 ID、日期、价格与方向 |
| [TradeMarkers.swift](../../SwiftKLineExample/TradeMarkers/TradeMarkers.swift) | 标记样式、协调、取消、重试与三角形渲染 |
| [TradeMarkerExample.swift](../../SwiftKLineExample/TradeMarkers/TradeMarkerExample.swift) | Provider 与配置组合 |
| [TradeMarkerTests.swift](../../SwiftKLineExample/TradeMarkers/Tests/TradeMarkerTests.swift) | 分页、隔离、边界与裁剪测试 |

这些类型不由 `SwiftKLine` 导出。以下代码应放在包含示例类型的应用模块中：

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

`SnapshotTradeProvider` 演示有限分页。`DemoTradeProvider` 通过独立行情查询生成模拟事件；真实成交应由应用账户服务提供。

此有限快照示例通过 `features: []` 关闭实时更新、恢复和内置持久化。仅替换 provider 闭包会保留范围会话；替换成交快照时更新示例插件的 `sourceID`，需要保留缓存重试时改变 `retryID`。修改 `maxCachedItems` 也会重建该插件的范围会话。

渲染器默认使用 8 pt 的绿色向上买入三角形和红色向下卖出三角形。多条事件可以映射到同一根真实 K 线。默认样式不扩展价格轴；是否纳入成交价格由应用决定。默认示例页面未启用该插件。
