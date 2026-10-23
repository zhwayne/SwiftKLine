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

周期和指标共用一个 `ChartSelection`，包含 `period: ChartPeriod` 与 `indicators: IndicatorSelection`。应用提供选择器 UI；库统一负责恢复、规范化、应用和持久化。`ChartConfiguration` 保存数据源与渲染声明，不再单独包含选择字段。

### 初始状态

| 优先级 | 来源 | 生效条件 |
|---|---|---|
| 1 | 已存储的 `ChartSelection` | 可以成功解码；空指标选择也是有效值 |
| 2 | 旧指标记录 + 初始周期 | 不存在完整的存储选择 |
| 3 | 传入初值 / SwiftUI 绑定初值 | 没有可用存储记录 |

静态 `configuration:` 便捷入口未传显式选择时，使用一分钟初始周期和外观默认指标。需要周期控件时使用下方配置工厂入口。

`availablePeriods` 按标识匹配并使用传入的规范周期，包括其名义秒数。不支持的周期回退到第一个有效可用项。空列表允许标识非空、秒数为正的自定义周期；无效输入使用有效初始周期，否则回退到一分钟。指标 ID 按可用性、面板归属和重复情况过滤，并保留原有顺序。

### 统一配置工厂

库先恢复存储周期，再构造配置并启动 provider。工厂应无副作用，且 `CandleSource.id` 应包含周期；只修改指标时可保留主数据会话。以下固定时长示例支持分钟、小时；日历周期仍需通过 `candleInterval:` 提供符合交易所规则的边界。

```swift
import SwiftKLine

@MainActor
func configuration(for selection: ChartSelection) -> ChartConfiguration {
    let period = selection.period
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
    // Validated periods, a nonempty source ID and no plugins make these declarations valid.
    return try! ChartConfiguration(source: source, appearance: .themed(.solaris), features: [])
}
```

### SwiftUI

```swift
import SwiftUI
import SwiftKLine

@MainActor
struct SelectableChart: View {
    @State private var selection = ChartSelection(period: .oneMinute,
        indicators: IndicatorSelection(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol, .macd]))
    @State private var store = UserDefaultsChartStateStore(namespace: "com.myapp.BTCUSDT")

    var body: some View {
        VStack {
            Picker("Period", selection: $selection.period) {
                Text("1m").tag(ChartPeriod.oneMinute)
                Text("1h").tag(ChartPeriod.oneHour)
            }
            KLineChart(selection: $selection, availablePeriods: [.oneMinute, .oneHour],
                       stateStore: store, configuration: configuration(for:))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
```

应用自定义的指标选择器绑定 `$selection.indicators`，周期选择器绑定 `$selection.period`。两者经过同一条图表状态流程，应用无需手动读写 store，也无需通过 `.onChange` 另行保存。

图表在 SwiftUI 更新周期之外异步回写恢复、规范化后的选择。后续绑定修改视为命令；新的用户修改优先于尚未执行的异步回写。值未变化的视图更新不会重复保存或重启 provider。可用选项变化导致的选择调整同样会规范化、保存并回写。

### UIKit

```swift
import SwiftKLine

@MainActor
func makePersistentChart(onSelectionChanged: @escaping (ChartSelection) -> Void) -> ChartView {
    let initial = ChartSelection(period: .oneMinute,
        indicators: IndicatorSelection(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol, .macd]))
    let chart = ChartView(selection: initial, availablePeriods: [.oneMinute, .oneHour],
        stateStore: UserDefaultsChartStateStore(namespace: "com.myapp.BTCUSDT"),
        configuration: configuration(for:))
    chart.selectionChanged = onSelectionChanged
    return chart
}
```

构造后立即读取 `chart.selection`，即可用恢复值初始化控件。通过 `setSelection(_:)` 提交完整选择；`selectionChanged` 在规范化并保存后报告实际变化。`resetSelectionToDefault()` 恢复初始周期及当前外观的默认指标。更新可用选项或工厂使用 `apply(selection:availablePeriods:configuration:)`；省略 selection 则保留当前选择。

### 共享状态存储

`ChartStateStore` 由库定义和使用，以一个内部键将完整 `ChartSelection` 保存为一条记录。传 `nil` 关闭持久化，使用 `MemoryChartStateStore()` 获得按实例隔离的临时状态，或用 `UserDefaultsChartStateStore(namespace:)` 保存不同图表的长期状态。store 在图表生命周期内固定，请保持实例和 namespace 稳定。

默认 namespace 为 `com.swiftkline`。库的旧指标记录会与传入的初始周期合并迁移；应用自有旧键的迁移由应用处理。应用也可复用基于 Data 的协议与类型安全 `ChartStateKey<Value>` 保存其他偏好；周期和指标选择均无需应用自定义键。

## 参数

默认参数写在上方默认序列 key 中。要使用自定义参数并保留选择状态与渲染能力，可按指标覆盖 key 列表：

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
let selection = IndicatorSelection(subIndicatorIDs: [.kdj, .dmi, .wr])
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
