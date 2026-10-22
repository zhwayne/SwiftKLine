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

`BuiltInIndicator` 枚举罗列全部选项（`.superTrend` 与 `.ichimoku` 使用短标题 `SUPER`、`ICHI`）。`IndicatorID` 提供稳定的开放 ID（如 `builtin.ma`），用于选择、持久化和插件替换。

## 指标选择

选择器是选择指标的内置 UI。UIKit 提供 `indicatorSelection`、`setIndicators(_:)` 和 `resetIndicatorsToDefault()`；SwiftUI 直接绑定选择状态。

| 等效 API | 结果 |
|---|---|
| `configuration.indicators` 变为一个新值 | 替换当前选择 |
| `configuration.indicators` 变为 `nil` | 恢复当前外观默认值 |
| 该值保持不变 | 保留用户选择，数据源变化时也一样 |
| 外观默认值变化 | 不重置当前选择 |
| `setIndicators(_:)` / `resetIndicatorsToDefault()` | 显式命令操作 |

### 初始状态

初始选择按优先级取第一个适用来源，然后过滤无效、重复、不可用或放错面板的 ID：

| 优先级 | 来源 | 生效条件 |
|---|---|---|
| 1 | 持久化选择 | 已启用持久化，且存储中的选择非空 |
| 2 | `configuration.indicators` | 提供了显式选择 |
| 3 | 外观默认值 | 前两项都没有提供选择 |

如果持久化选择在规范化后变为空，图表会保留这个空结果，不再回退到配置或外观默认值。

### 持久化

启用 `.indicatorPersistence`（属于 `features: .all`）后，选择在图表创建时读取，并在初始规范化以及选择器、set、reset 命令后保存。仅应用配置不会保存处理后的选择。为已有图表开启持久化不会重新读取存储。

默认 `UserDefaultsIndicatorSelectionStore` 的存储键由不同数据源和图表共用。UIKit 可注入不同键的存储以隔离；`KLineChart` 不提供存储注入——应用自行存储时，可关闭内置持久化并通过选择状态绑定管理。

## 参数

默认参数写在上方默认序列 key 中。要使用自定义参数并保留选择器与渲染能力，可按指标覆盖 key 列表：

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
