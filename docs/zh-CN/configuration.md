# 配置与集成

[English](../configuration.md) | **简体中文**

[文档索引](README.md) · [快速开始](getting-started.md) · [数据源](data-providers.md)

UIKit 的 `ChartView` 与 SwiftUI 的 `KLineChart` 共用 `ChartConfiguration`。请在主 actor 上创建并应用配置。本页是配置内容与图表更新行为的参考；外观值本身见[外观定制](appearance.md)。

## 配置字段

| 字段 | 用途 | 默认值 |
|---|---|---|
| `source` | Provider 工厂、会话语义 ID 和 K 线边界 | 必填 |
| `appearance` | 主题、尺寸、面板、图例、水印与指标参数 | `ChartAppearance()` |
| `content` | 主图展示方式 | `.candlestick` |
| `plugins` | 有序的业务功能列表，ID 必须非空且唯一 | `[]` |
| `indicators` | 内置选择器的初始状态 | 先持久化，再外观默认值 |
| `features` | 加载与选择状态持久化能力 | `.all` |

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

校验发生在构造时，不影响正在运行的图表：

- `ChartConfigurationError.emptySourceID` — 数据源必须有非空语义 ID。
- `ChartConfigurationError.emptyPluginID` 与 `.duplicatePluginID(_:)` 覆盖插件列表。
- 固定周期时长必须为有限正数，这是前置条件，不属于可抛出的配置错误。

修改插件列表需要创建新配置，让校验在图表更新之前完成。

## 主图展示

`content` 在 `.candlestick` 与 `.timeSeries` 之间选择主图呈现方式，与指标选择无关：

- `.timeSeries` 隐藏主图插件中 ID 解析为内置指标的插件，并隐藏 K 线高低点标注。最新价格标签、价格指示线和返回最新位置控件在两种模式中均显示。
- 使用应用专属 ID 的 `.main` 自定义插件在两种模式中均绘制。
- 隐藏一个内置指标不会移除其计算器；它仍处于选中状态，也可能继续计算。

仅修改 `content` 会切换呈现，不重启 provider。

## 数据源标识与更新

`CandleSource.id` 应标识交易对、周期、交易场所和日历语义，例如 `exchange:BTCUSDT:1m:UTC`。工厂在图表会话启动时调用。相同 ID 下重建闭包不会替换已有 provider——原因见数据源指南。

一份稳定的配置经过 `chart.apply(_:)`(UIKit)或 updated props(SwiftUI)时按差异调和，而非整体重启：

| 变更 | 效果 |
|---|---|
| 数据源 ID 与加载能力不变 | 保留主数据会话 |
| 数据源 ID 改变 | 取消旧数据与计算任务，清空主数据，重建插件协调器 |
| `.liveUpdates` 或 `.gapRecovery` 改变 | 重建主会话和插件协调器 |
| 插件 ID 与具体类型不变 | 更新现有协调器 |
| 插件重排 | 保留协调器状态，调整面板与绘制顺序 |
| 插件移除或具体类型改变 | 撤销上下文，然后清理旧资源 |
| 外观改变 | 重新绘制；仅使参数变化的计算失效 |
| 仅 `content` 改变 | 切换展示，不重启 provider |

参数变化时保持插件 ID 稳定；拥有协调器的是 ID，而不是参数值。插件的账户或查询身份由插件自身管理，与主数据源身份分开。

共用的一个配置值从不共享运行时状态：每个图表实例拥有自己的会话、协调器和图层。

## 加载能力

| 能力 | 效果 |
|---|---|
| `.liveUpdates` | 消费完整的实时 K 线快照 |
| `.gapRecovery` | 回到前台或网络恢复时，若已知最后时间戳则尝试恢复区间 |
| `.indicatorPersistence` | 读取和写入内置选择器状态 |
| `.all` | 启用以上三项 |
| `[]` | 静态图表与确定性测试 |

启用持久化后，UIKit 可注入 `IndicatorSelectionStore`;SwiftUI 不注入存储，应用自行存储时可使用选择状态绑定并关闭内置持久化。图表活跃状态跟随窗口、场景与应用状态：进入后台或非活跃场景会取消实时消费与恢复请求，而在途的历史页继续加载。回到前台或网络恢复仅在启用 `.gapRecovery` 且已知最后时间戳时触发恢复；即使本次恢复报错，恢复尝试结束后也会重新消费实时流。

## 错误处理

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

- `onLoadError` 在主 actor 上报告历史页与恢复失败。失败的页不消耗页码，下一次靠近左边缘的请求会重试。主加载器没有公开 `retry()` API，也不会定时自动重试。
- `onPluginError` 报告带插件 ID 的错误。插件自身的数据问题不应延迟 K 线与指标；图表继续使用其余功能。
- 实时传输的重连由 provider 负责。库永远不会自行重连实时流。

## 图表 API

`ChartView`（UIKit）与 `KLineChart`（SwiftUI）通过各自的平台方式暴露相同操作：

| 操作 | UIKit | SwiftUI |
|---|---|---|
| 调和配置 | `apply(_:)` | 传入更新后的 `configuration` |
| 读取选择状态 | `indicatorSelection` | `indicators` 绑定 |
| 替换选择 | `setIndicators(_:)` | 给绑定赋新值 |
| 恢复默认 | `resetIndicatorsToDefault()` | 适配器不暴露；通过配置或绑定管理 |
| 回到最新 | `scrollToLatest()` | 适配器不暴露；系统回到顶部手势同样指向最新 K 线 |
| 选择状态持久化 | `indicatorSelectionStore:` 初始化参数 | 适配器不暴露；传入绑定或使用默认存储 |
| 加载错误 | `onLoadError` | `onLoadError` 初始化参数 |
| 插件错误 | `onPluginError` | `onPluginError` 初始化参数 |
| 选择变化 | `indicatorSelectionChanged` | 绑定接收用户变化 |

SwiftUI 注意事项：

- 不要把动态配置放进只在初始化时赋值一次的 `@State`；配置应保存在应用模型中，并向视图传递更新后的值。
- 创建视图即启动会话；适配器在视图移除时结束会话。

## 常见接入问题

| 现象 | 检查项 |
|---|---|
| 新快照没有显示 | 更换数据源 ID；仅替换工厂闭包会保留旧会话 |
| 启动后的指标选择不符预期 | 检查持久化状态、外观默认值和 SwiftUI 绑定 |
| 切换周期或交易对后残留旧数据 | 整体更换 `CandleSource.id`；相同 ID 不会重新调用工厂 |
| 事件映射到错误 K 线 | 使用 Unix 秒和真实 K 线边界，参见[时间规则](data-providers.md#时间与边界) |
| 图表高度不符预期 | 检查副图面板、选择器与父容器约束 |
| 无法导入自定义类型 | 成交标记类型属于示例代码；需在应用中实现或复制 |
