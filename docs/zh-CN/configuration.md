# 配置与集成

[English](../configuration.md) | **简体中文**

[文档索引](README.md) · [快速开始](../../README.zh-CN.md#快速开始)

UIKit 的 `ChartView` 与 SwiftUI 的 `KLineChart` 共用 `ChartConfiguration`。在 `MainActor` 上创建并应用配置。

## 配置字段

| 字段 | 用途 | 默认值 |
|---|---|---|
| `source` | Provider 工厂、会话语义 ID 和 K 线边界 | 必填 |
| `appearance` | 主题、尺寸、面板、图例与指标参数 | `ChartAppearance()` |
| `content` | 主图展示方式 | `.candlestick` |
| `plugins` | 有序的业务功能列表，ID 必须非空且唯一 | `[]` |
| `indicators` | 内置选择器的初始状态 | 外观默认值，受持久化状态影响 |
| `features` | 加载与选择状态存储能力 | `.all` |

`ChartConfiguration` 可能抛出 `ChartConfigurationError` 中的 `emptySourceID`、`emptyPluginID` 或 `duplicatePluginID(_:)`。修改插件列表需要创建新配置，让校验在更新图表之前完成。固定周期时长必须为有限正数，这是前置条件，不属于可抛出的配置错误。

## 静态与网络数据源

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

`SnapshotProvider` 捕获一个有限数组。替换快照需要更换数据源 ID。连续更新的数据由工厂返回自定义 `ChartItemProvider`，详见[数据源](data-providers.md)。

## 标识与更新

数据源 ID 应标识交易对、周期、交易场所和日历语义，例如 `exchange:BTCUSDT:1m:UTC`。工厂仅在会话启动时调用；相同 ID 下重建闭包不会替换已有 provider。

| 变更 | 效果 |
|---|---|
| 数据源 ID 与加载开关不变 | 保留主数据会话 |
| 数据源 ID 改变 | 取消旧数据和计算任务，清空主数据并重建插件协调器 |
| `.liveUpdates` 或 `.gapRecovery` 改变 | 重建主会话和插件协调器 |
| 插件 ID 与具体类型不变 | 更新现有协调器 |
| 插件重排 | 保留协调器状态，调整面板与绘制顺序 |
| 插件移除或具体类型改变 | 撤销上下文并清理旧资源 |
| 外观改变 | 更新绘制；计算参数改变时使对应输出失效 |
| 仅展示模式改变 | 切换展示，不重启 provider |

参数变化时保持插件 ID 稳定。插件的账户或查询身份由自身管理，与主数据源身份分开。自定义 ID 使用应用专属前缀，`builtin.` 为内置指标保留。声明与内置指标 ID 完全相同的插件会替换选择器生成的对应插件；分时模式还会隐藏使用已知内置 ID 的主图插件。

UIKit 使用 `chart.apply(configuration)`。SwiftUI 向 `KLineChart` 传入更新后的配置，不要把父视图传来的动态输入放进仅初始化一次的 `@State`。即使共用同一个配置值，每个图表仍创建自己的会话。

## 指标与选择状态

选择器支持 MA、EMA、WMA、BOLL、SAR、BBI、VWMA、Donchian、SuperTrend（SUPER）、Ichimoku（ICHI）、VOL、RSI、MACD、KDJ、CCI、WR、DMI、ATR、OBV、ROC、MFI、TRIX。通过 `ChartAppearance.indicators` 配置可选项，通过 `defaultMainIndicators` / `defaultSubIndicators` 配置默认与重置值，通过 `indicatorKeyOverrides` 配置参数。

初始选择按以下优先级取第一个适用来源，然后过滤无效、重复、不可用或放错面板的 ID：

| 优先级 | 来源 | 生效条件 |
|---|---|---|
| 1 | 持久化选择 | 已启用持久化，且存储中的选择非空 |
| 2 | `configuration.indicators` | 提供了显式选择 |
| 3 | 外观默认值 | 前两项都没有提供选择 |

如果持久化选择在规范化后变为空，图表会保留这个空结果，不再回退到配置或外观默认值。选择器控制内置指标；业务功能通过 `plugins` 声明。

后续更新遵循以下规则：

| 更新 | 结果 |
|---|---|
| `configuration.indicators` 变为一个新值 | 替换当前选择 |
| `configuration.indicators` 变为 `nil` | 恢复当前外观默认值 |
| 该值保持不变 | 保留用户选择，数据源变化时也一样 |
| 仅外观默认值变化 | 不重置当前选择 |

需要显式操作时使用 `setIndicators(_:)` 或 `resetIndicatorsToDefault()`。

持久化在图表创建时读取，在初始规范化及选择器、set、reset 命令后保存。仅应用配置不会保存处理后的选择。为已有图表开启持久化也不会重新读取存储。默认 `UserDefaultsIndicatorSelectionStore` 的存储键由不同数据源和图表共用；UIKit 可注入不同键的存储以隔离。`KLineChart` 不提供存储注入；应用自行存储时，可使用选择状态绑定并关闭内置持久化。

UIKit 提供 `indicatorSelection`、`setIndicators(_:)` 和 `resetIndicatorsToDefault()`。SwiftUI 可以绑定选择状态：

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

提供绑定后，每次 SwiftUI 更新以绑定值为准。适配器将其同步到 UIKit，并回传后续用户选择，避免在同步过程中写入 SwiftUI 状态。UIKit 过滤掉的 ID 不会在这次同步中自动回写。选择器变化不会重启主 provider，也不会重建身份未变的业务插件协调器。

### 新增附图指标

每个选中指标对应一个独立面板，同一指标的多组参数共用该面板。示例的默认选择仍为 VOL、MACD。

| 指标 | 默认参数与输出 | 首个有效索引 / 行为 |
|---|---|---|
| KDJ | (9, 3, 3)，K/D/J | period − 1；K/D 初始值 50，递归权重为 1/kPeriod、1/dPeriod；J = 3K − 2D |
| CCI | 20，典型价 CCI | period − 1；典型价 (H+L+C)/3，常数 0.015，精确平均绝对偏差 |
| WR | 14，Williams %R | period − 1；国际 −100...0 刻度 |
| DMI | (14, 14)，+DI/−DI/ADX | DI 位于 diPeriod，ADX 位于 diPeriod + adxPeriod − 1；Wilder 平滑，不含 ADXR |
| ATR | 14，真实波幅的 Wilder RMA | period − 1；首根 TR = H−L，以完整窗口均值播种 |
| OBV | 无周期，累计有符号成交量 | 0；初始值为 0，收盘持平时不变 |
| ROC | 9，收盘价变化百分比 | period；100 × (close / historicalClose − 1)，无信号线 |
| MFI | 14，典型价资金流 | period；按典型价涨跌归类成交量加权资金流 |
| TRIX | 18，三重 EMA 单期变化百分比 | 3 × (period − 1) + 1；每级 EMA 使用完整 SMA 播种，无信号线 |

索引从零开始。输出与输入等长，预热阶段为 nil；DMI 在 ADX 预热时先发布 DI 双线。非正周期返回对齐的 nil。CCI 平均偏差为零时输出 0；KDJ 平盘窗口取 RSV 50；WR 高低价相等时输出 nil；ROC/TRIX 分母为零时输出 nil。DMI 方向变化相等、TR 为零或 DI 总和为零时贡献为 0。MFI 只有正流时为 100，只有负流时为 0，两者均无时为 nil。这些约定明确库内初始化行为，不承诺跨平台或不同历史起点下逐点一致。

参考线为 KDJ/MFI 的 20、80，WR 的 −80、−20，CCI 的 −100/0/100，DMI 的 20/25，以及 ROC/TRIX 的 0。KDJ 纵轴包含超出 0...100 的 J 值；ATR 纵轴包含零；OBV 按可见值缩放。缺失或非有限值会断开路径；图例跟随选中 K 线或最后一根可见 K 线。

参数与颜色均使用完整 key。单线使用 `LineStyle`，复合输出使用公开的 `KDJStyle`、`DMIStyle`。自定义 key 没有匹配样式时回退到可读颜色。显式样式字典会替换默认值：

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

仅使用 Core 时可直接实例化 `KDJCalculator`、`CCICalculator`、`WRCalculator`、`DMICalculator`、`ATRCalculator`、`OBVCalculator`、`ROCCalculator`、`MFICalculator`、`TRIXCalculator`。KDJ 返回 `KDJIndicatorValue`，DMI 返回 ADX 可选的 `DMIIndicatorValue`，其余返回 Double。更新采用全量重算。

公式参考：[KDJ](https://support.futunn.com/topic149)、[CCI](https://www.tradingview.com/support/solutions/43000502001-commodity-channel-index-cci/)、[DMI](https://www.tradingview.com/support/solutions/43000502250-directional-movement-dmi/)、[ATR](https://www.tradingview.com/support/solutions/43000501823-average-true-range-atr/)、[OBV](https://www.tradingview.com/support/solutions/43000502593-on-balance-volume-obv/)、[MFI](https://www.tradingview.com/support/solutions/43000502348-money-flow-mfi/) 和 [TRIX](https://www.tradingview.com/support/solutions/43000502331-trix/)。

## 外观与布局

`.themed(.solaris)` 提供明亮预设，`.themed(.midnight)` 提供深色预设。直接构造 `ChartAppearance` 可以设置蜡烛样式、布局、图例字体和水印文字。

指标样式由包含参数的完整 `SeriesKey` 索引。显式传入样式字典会替换默认字典。缺少匹配的 `LineStyle` 时，`LineIndicatorRenderer` 使用标签颜色。

图表固有高度包含主图、时间轴、副图和选择器。UIKit 中提供水平方向约束；SwiftUI 中使用 `.fixedSize(horizontal: false, vertical: true)` 接受固有高度。

`.timeSeries` 隐藏使用已知内置 ID 的主图插件和 K 线高低点标注。最新价格标签、价格指示线和返回最新位置控件在两种模式中均保留。分时折线下方的面积填充从上到下逐渐透明。使用应用专属 ID 的自定义 `.main` 插件在两种模式中均绘制。隐藏的内置指标仍处于选中状态，也可能继续计算。

## 加载与错误

| 能力 | 效果 |
|---|---|
| `.liveUpdates` | 消费完整的实时 K 线快照 |
| `.gapRecovery` | 回到前台或网络恢复时，若已知最后时间戳则尝试恢复区间 |
| `.indicatorPersistence` | 读取和写入内置选择器状态 |
| `.all` | 启用以上三项 |

静态图表或确定性测试可使用 `[]`。关闭持久化时不读写选择状态存储；开启时，UIKit 使用方可向 `ChartView` 注入 `IndicatorSelectionStore`。

`onLoadError` 报告历史和恢复错误；`onPluginError` 报告带插件 ID 的错误。`ChartView` 与 `KLineChart` 初始化器均支持这两个入口。Provider 负责实时传输和重连行为。

窗口、场景和应用状态共同决定图表活跃状态。初始化会启动首个历史请求，并在启用时开始实时消费。进入非活跃状态会取消实时消费和恢复请求，但不会取消正在进行的历史页。回到前台或网络恢复可在启用恢复能力且已知最后时间戳时触发恢复。恢复尝试结束后会重新消费实时流，即使本次恢复报错。业务插件通过 `context.input.isActive` 管理自己的请求和取消。

## 常见接入问题

| 现象 | 检查项 |
|---|---|
| 新快照没有显示 | 更换数据源 ID；仅替换工厂闭包会保留旧会话 |
| 启动后的指标选择不符预期 | 检查持久化状态、外观默认值和 SwiftUI 绑定 |
| 事件映射到错误 K 线 | 使用 Unix 秒和真实 K 线边界，参见[时间规则](data-providers.md#时间与边界) |
| 图表高度不符预期 | 检查副图、选择器与父容器约束 |
| 无法导入自定义类型 | 成交标记类型属于示例，需在应用中实现或引入 |
