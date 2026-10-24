# 配置与集成

[English](../configuration.md) | **简体中文**

[文档索引](README.md) · [快速开始](getting-started.md) · [数据源](data-providers.md)

库中的 UIKit `ChartView` 消费 `ChartConfiguration`。SwiftUI 应用自行提供桥接，参考示例的 [KLineChart](../../SwiftKLineExample/KLineChart.swift)。请在主 actor 上创建并应用配置。本页是配置内容与图表更新行为的参考；外观值本身见[外观定制](appearance.md)。

## 配置字段

| 字段 | 用途 | 默认值 |
|---|---|---|
| `source` | Provider 工厂、会话语义 ID 和 K 线边界 | 必填 |
| `appearance` | 主题、尺寸、图例、水印与序列样式 | `ChartAppearance()` |
| `indicatorConfiguration` | 内置指标的计算 key 与参数 | `IndicatorConfiguration()` |
| `content` | 主图展示方式 | `.candlestick` |
| `plugins` | 有序的业务功能列表，ID 必须非空且唯一 | `[]` |
| `features` | K 线加载能力 | `.all` |

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

校验发生在构造时，不影响正在运行的图表：

- `ChartConfigurationError.emptySourceID` — 数据源必须有非空语义 ID。
- `ChartConfigurationError.emptyPluginID` 与 `.duplicatePluginID(_:)` 覆盖插件列表。
- 固定周期时长必须为有限正数，这是前置条件，不属于可抛出的配置错误。
- 蜡烛宽度必须为有限正数，间距必须为有限非负数，合计步长必须有限；面板高度必须有限且非负。这些构造前置条件不引入 UI 错误处理链，布局转换也会拒绝非有限或整数无法表示的索引。

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
| 外观改变 | 重新绘制，保留计算结果 |
| 指标计算 key 改变 | 重算受影响的序列并协调 renderer |
| 输入未变化 | 跳过内置指标协调和重绘；自定义插件仍接收更新 |
| 仅 `content` 改变 | 切换展示，不重启 provider |

参数变化时保持插件 ID 稳定；拥有协调器的是 ID，而不是参数值。插件的账户或查询身份由插件自身管理，与主数据源身份分开。

共用的一个配置值从不共享运行时状态：每个图表实例拥有自己的会话、协调器和图层。

## 加载能力

| 能力 | 效果 |
|---|---|
| `.liveUpdates` | 消费完整的实时 K 线快照 |
| `.gapRecovery` | 回到前台或网络恢复时，若已知最后时间戳则尝试恢复区间 |
| `.all` | 启用实时更新和缺口恢复 |
| `[]` | 静态图表与确定性测试 |

示例应用通过自有的 `ChartStateStore` 恢复和保存 `ChartPreferences`；这些类型属于示例源码，不是库导出。存储独立于图表生命周期；`UserDefaultsChartStateStore(namespace:)` 隔离不同图表的偏好。详见[共享状态存储](indicators.md#共享状态存储)。

图表活跃状态跟随窗口、场景与应用状态：进入后台或非活跃场景会取消实时消费与恢复请求，而在途的历史页继续加载。新数据源继承当前活跃状态，非活跃会话可以加载历史，但不订阅实时流。活跃状态命令用修订号拒绝迟到的 actor 消息；网络恢复不会重新激活已暂停的会话。回到前台或网络恢复仅在启用 `.gapRecovery` 且已知最后时间戳时触发恢复；即使本次恢复报错，恢复尝试结束后也会重新消费实时流。

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

`ChartView` 接收配置与独立的指标选择值。下表 SwiftUI 列描述应用自有的示例包装：

| 操作 | UIKit | SwiftUI |
|---|---|---|
| 协调配置 | `apply(_:)` | 传入更新后的 `configuration` |
| 读取请求的指标 | `indicators` | 应用自有状态 |
| 读取支持的指标 | `resolvedIndicators` | `indicators.resolved(availableIndicators:)` |
| 替换指标 | `setIndicators(_:)` | 传入更新后的 `indicators` |
| 同时更新两项输入 | `apply(_:indicators:)` | 传入两项更新后的值 |
| 恢复默认 | 显式提供应用默认值 | 修改应用状态 |
| 滚动到最新 | `scrollToLatest()` | 适配器未暴露；系统滚动到顶部手势也会定位最新 K 线 |
| 结束图表会话 | `shutdown()` | 应用包装在 `dismantleUIView` 中调用 |
| 加载错误 | `onLoadError` | `onLoadError` 初始化参数 |
| 插件错误 | `onPluginError` | `onPluginError` 初始化参数 |
| 状态存储 | 应用示例偏好 | 应用示例偏好 |

应用管理周期、可用选项、控件、恢复和保存。在构造第一份配置之前恢复并校验偏好；周期变化生成新的数据源声明，指标变化只调整所选内置指标。图表派生支持的指标，不修改请求状态，也不回写绑定。显式声明的插件独立于指标选择。

`shutdown()` 是永久终止操作，重复调用无副作用；之后的配置、指标和活跃状态更新都被忽略，通知观察者和待执行绘制会清理。重新加载须创建新的 ChartView。

只有已知不可变的内置样式与完整内置声明相同时才跳过工作。自定义插件每次仍收到 update，应通过 context 请求资源变化或重绘。所有自定义样式均保守地触发绘制，包括符合 Equatable 的引用类型以及可能共享可变状态的值。

SwiftUI 注意事项：

- 不要把动态配置放进只在初始化时赋值一次的 `@State`；配置应保存在应用模型中，并向视图传递更新后的值。
- 创建视图即启动会话；适配器在视图移除时结束会话。

## 常见接入问题

| 现象 | 检查项 |
|---|---|
| 新快照没有显示 | 更换数据源 ID；仅替换工厂闭包会保留旧会话 |
| 启动后的指标选择不符预期 | 检查应用偏好、请求的指标和外观中的可用指标 |
| 切换周期或交易对后残留旧数据 | 在配置工厂中将周期或交易对纳入 `CandleSource.id`；相同 ID 不会重建会话 |
| 事件映射到错误 K 线 | 使用 Unix 秒和真实 K 线边界，参见[时间规则](data-providers.md#时间与边界) |
| 图表高度不符预期 | 检查副图面板与父容器约束；应用控件位于图表之外 |
| 无法导入自定义类型 | 成交标记类型属于示例代码；需在应用中实现或复制 |
