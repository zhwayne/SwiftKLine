# 内置指标

[English](../indicators.md) | **简体中文**

[文档索引](README.md) · [配置](configuration.md) · [外观](appearance.md)

SwiftKLine 内置 22 个指标。每个指标与应用自定义插件走同一条插件流水线：每个序列 key 一个计算器和一至多个渲染器，由图表统一协调。内置 ID 命名空间 `builtin.*` 为内置指标保留；自定义功能使用应用专属前缀。

## 指标目录

主图指标叠加在价格图表上。副图指标各自占用一个独立下方面板；同一副图指标的多组参数共用该面板。

| 指标 | 面板 | 默认序列 key | 输出 |
|---|---|---|---|
| MA | 主图 | `.ma(period:)` 5、10、20 | `Double` |
| EMA | 主图 | `.ema(period:)` 5、10、20 | `Double` |
| WMA | 主图 | `.wma(period:)` 5、10、20 | `Double` |
| BOLL | 主图 | `.boll(period: 20, k: 2.0)` | `BOLLIndicatorValue`（中轨/上轨/下轨） |
| SAR | 主图 | `.sar`（af 0.02 / 0.02 / 0.2） | `Double` |
| BBI | 主图 | `.bbi`（周期 3、6、12、24） | `Double` |
| VWMA | 主图 | `.vwma(period: 20)` | `Double` |
| Donchian | 主图 | `.donchian(period: 20)` | `BandIndicatorValue`（上中下轨） |
| SUPER（SuperTrend） | 主图 | `.superTrend(period: 10, multiplier: 3)` | 方向跟踪线 |
| ICHI（Ichimoku） | 主图 | `.ichimoku(9, 26, 52, 26)` | 五线云图叠加 |
| VOL | 副图 | `.vol` | 按涨跌着色的成交量 |
| RSI | 副图 | `.rsi(period:)` 6、12、24 | `Double` |
| MACD | 副图 | `.macd(short: 12, long: 26, signal: 9)` | `MACDIndicatorValue`（macd/signal/histogram） |
| KDJ | 副图 | `.kdj(period: 9, kPeriod: 3, dPeriod: 3)` | `KDJIndicatorValue`（K/D/J） |
| CCI | 副图 | `.cci(period: 20)` | `Double` |
| WR | 副图 | `.wr(period: 14)` | `Double`（−100…0 刻度） |
| DMI | 副图 | `.dmi(diPeriod: 14, adxPeriod: 14)` | `DMIIndicatorValue`（+DI/−DI/ADX） |
| ATR | 副图 | `.atr(period: 14)` | `Double` |
| OBV | 副图 | `.obv` | `Double`，累计值 |
| ROC | 副图 | `.roc(period: 9)` | `Double`，百分比 |
| MFI | 副图 | `.mfi(period: 14)` | `Double` |
| TRIX | 副图 | `.trix(period: 18)` | `Double`，百分比 |

`BuiltInIndicator` 枚举罗列全部选项（`.superTrend` 与 `.ichimoku` 使用短标题 `SUPER`、`ICHI`）。`IndicatorID` 提供稳定的开放 ID（如 `builtin.ma`），用于选择、应用持久化和插件替换。

## 指标选择

应用管理周期和指标控件。`ChartConfiguration` 描述数据源、外观和插件，`IndicatorSelection` 单独传入内置指标选择。图表消费这些值，不读取存储，也不回写应用状态。

### 初始状态

省略 `indicators:` 表示不选择内置指标。`ChartView.indicators` 保留传入请求，`resolvedIndicators` 按顺序派生库支持、位置正确且不重复的指标。默认选择和可用选项由应用管理；保留原始偏好，将 `indicators.resolved(availableIndicators: available)` 传给图表，暂不可用的指标就能在恢复支持后重新显示。

自定义插件在 `ChartConfiguration.plugins` 中声明。指标选择不会开关自定义插件或显式声明的内置插件；ID 重叠时显式声明优先。

### 周期配置

应用在构造数据源前校验周期。将周期及日历语义纳入 `CandleSource.id`，仅修改指标就能保留 provider。本例使用固定时长的分钟与小时周期；日历周期仍需提供交易所相关的 `candleInterval:` 规则。

```swift
import SwiftKLine

@MainActor
func configuration(for period: ChartPeriod) -> ChartConfiguration {
    let source = CandleSource(
        id: "demo:\(period.identifier):\(period.seconds)",
        duration: Double(period.seconds)
    ) {
        let candles = (0..<60).map { index in
            Candle(timestamp: 1_700_000_000 + index * period.seconds,
                   open: 100, high: 102, low: 99, close: 101, volume: 1_000)
        }
        return SnapshotProvider(items: candles)
    }
    return try! ChartConfiguration(source: source, appearance: .themed(.solaris), features: [])
}
```

### SwiftUI

SwiftUI 桥接属于应用层。先将示例中的 [KLineChart.swift](../../SwiftKLineExample/KLineChart.swift) 加入你的应用 target；下面的 `KLineChart` 是这段应用代码，不由库导出。

```swift
import SwiftUI
import SwiftKLine

@MainActor
struct SelectableChart: View {
    @State private var period: ChartPeriod = .oneMinute
    @State private var indicators = IndicatorSelection(
        mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol, .macd])

    var body: some View {
        VStack {
            Picker("Period", selection: $period) {
                Text("1m").tag(ChartPeriod.oneMinute)
                Text("1h").tag(ChartPeriod.oneHour)
            }
            KLineChart(configuration: configuration(for: period), indicators: indicators)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
```

应用自有的指标控件绑定 `$indicators`，图表只接收当前值；周期变化重新生成配置。适配器负责输入转发、尺寸协商和清理，不再进行绑定同步或持久化。

### UIKit

```swift
import SwiftKLine

@MainActor
func makeChart(period: ChartPeriod, indicators: IndicatorSelection) -> ChartView {
    ChartView(configuration: configuration(for: period), indicators: indicators)
}
```

使用 `setIndicators(_:)` 更新内置指标，`apply(_:)` 更新配置并保留请求的指标，或通过 `apply(_:indicators:)` 同时更新两者。重置时显式传入应用定义的默认值。主题切换不选择指标，也不修改计算参数。

### 共享状态存储

`ChartPreferences`、`ChartStateStore` 及迁移代码属于示例应用，不由库导出。需要复用时复制示例的 [Preferences 目录](../../SwiftKLineExample/Preferences)。应用自有的 `ChartScreenState` 在构造数据源前恢复并校验一次，跨视图更新保留偏好，仅在周期或指标实际变化时保存。App 持有该可观察实例，ContentView 通过 `@Bindable` 接收。预览使用隔离的离线状态。

```swift
import SwiftKLine

@MainActor
func restorePreferences(from store: any ChartStateStore) -> ChartPreferences {
    let defaults = ChartPreferences(period: .oneMinute,
        indicators: IndicatorSelection(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol]))
    var restored = ChartPreferences.restore(from: store, defaults: defaults)
    let availablePeriods: [ChartPeriod] = [.oneMinute, .oneHour]
    restored.period = availablePeriods.first { $0.identifier == restored.period.identifier } ?? defaults.period
    restored.indicators = restored.indicators.resolved(availableIndicators: BuiltInIndicator.allCases)
    restored.save(to: store)
    return restored
}
```

`ChartPreferences.restore(from:defaults:)` 按顺序读取首个可解码的记录：`chart.preferences`、旧 `chart.selection`、旧 `indicator.selection` 搭配默认周期，最后使用传入默认值。空指标选择是有效值。恢复不写入、不校验；`save(to:)` 保存新格式。兼容 JSON 和历史 property list。

`UserDefaultsChartStateStore(namespace:)` 用 namespace 隔离图表，默认是 `com.swiftkline`；`MemoryChartStateStore()` 按实例隔离。应用也可用类型安全的 `ChartStateKey<Value>` 复用 Data 存储协议。应用中的 `.chartPreferences` key 支持显式删除；若重置存储时不希望回退到旧偏好，还应删除历史记录。

## 参数

默认参数写在上方默认序列 key 中。通过 `ChartConfiguration.indicatorConfiguration` 传入独立的计算参数；`ChartAppearance` 仅保存视觉样式：

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
    ]
)
let parameters = IndicatorConfiguration(seriesKeys: [
    .kdj: [kdjKey],
    .dmi: [dmiKey],
    .wr: [.wr(period: 14), .wr(period: 7)]
])
let selection = IndicatorSelection(subIndicatorIDs: [.kdj, .dmi, .wr])
let config = try ChartConfiguration(
    source: CandleSource(id: "parameters-demo", duration: 60) { SnapshotProvider(items: []) },
    appearance: appearance,
    indicatorConfiguration: parameters,
    features: []
)
```

图表对覆盖列表的处理规则：

- 无法解析参数或与所属指标不匹配的 key 会被跳过，而不是猜测兜底。
- 自定义参数 key 需要配套样式；见[指标样式](appearance.md#指标样式)。
- 参数变化会重算受影响的序列；key 集合不变时复用渲染器。

## 参考线

副图指标绘制固定参考线：KDJ/MFI 的 20、80，WR 的 −80、−20，CCI 的 −100/0/100，DMI 的 20、25，ROC/TRIX 的 0。KDJ 纵轴包含超出 0…100 的 J 值；ATR 纵轴包含零；OBV 按可见值缩放。缺失或非有限值会断开路径；图例跟随选中 K 线或最后一根可见 K 线。

## 在 Core 中直接使用计算器

`SwiftKLineCore` 导出全部计算器实现，无 UIKit 环境或跨平台计算可直接使用：

| 计算器 | 输出值 |
|---|---|
| `MACalculator(period:)`、`EMACalculator`、`WMACalculator`、`VWMACalculator` | `Double` |
| `BOLLCalculator(period:k:)`、`DonchianCalculator` | `BandIndicatorValue` |
| `SARCalculator`、`BBICalculator(periods:)` | `Double` |
| `SuperTrendCalculator(period:multiplier:)`、`IchimokuCalculator` | 类型化叠加值 |
| `RSICalculator`、`CCICalculator`、`WRCalculator`、`ATRCalculator`、`ROCCalculator` | `Double` |
| `KDJCalculator(period:kPeriod:dPeriod:)`、`DMICalculator(diPeriod:adxPeriod:)` | 类型化组合值 |
| `MACDCalculator(shortPeriod:longPeriod:signalPeriod:)` | `MACDIndicatorValue` |
| `VOLCalculator`、`OBVCalculator`、`MFICalculator`、`TRIXCalculator` | `Double` |

```swift
import SwiftKLineCore

func macdBars(from candles: [any ChartItem]) -> [MACDIndicatorValue?] {
    MACDCalculator(shortPeriod: 12, longPeriod: 26, signalPeriod: 9)
        .calculate(for: candles)
}
```

所有计算器共享的输出约定：

- 每根输入 K 线对应一个可选输出，顺序与输入一致；预热位置为 `nil`。
- 非正周期返回对齐的 `nil` 输出，不抛错。
- `calculate(for:)` 不排序、不修改输入。
- `update(for:values:from:)` 默认全量重算；在未变化前缀与参数保持有效的前提下，实现可以提供更快的后缀路径。
- 复用上一次输出做后缀更新要求计算语义不变；数据源替换、前插历史或参数变化必须从下标 0 重新计算。

要并行计算一批序列，可把 `AnyIndicatorCalculator` 包装传入 `IndicatorEngine.calculate(items:calculators:previous:invalidatedFrom:)`。引擎以结构化子任务运行各计算器，并按声明顺序确定合并结果（后者覆盖），与任务完成顺序无关。

## 公式参考

KDJ、CCI、DMI、ATR、OBV、MFI、TRIX 参考公开定义：

[KDJ](https://support.futunn.com/topic149)、[CCI](https://www.tradingview.com/support/solutions/43000502001-commodity-channel-index-cci/)、[DMI](https://www.tradingview.com/support/solutions/43000502250-directional-movement-dmi/)、[ATR](https://www.tradingview.com/support/solutions/43000501823-average-true-range-atr/)、[OBV](https://www.tradingview.com/support/solutions/43000502593-on-balance-volume-obv/)、[MFI](https://www.tradingview.com/support/solutions/43000502348-money-flow-mfi/)、[TRIX](https://www.tradingview.com/support/solutions/43000502331-trix/)

这些约定明确本库的初始化行为；不承诺不同平台或不同历史起点下逐点一致。
