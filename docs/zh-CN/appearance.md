# 外观定制

[English](../appearance.md) | **简体中文**

[文档索引](README.md) · [内置指标](indicators.md) · [配置](configuration.md)

所有视觉设置都来自 `ChartAppearance`，它是 `ChartConfiguration` 的一部分。外观更新会立即应用并重新绘制，不会重启数据源或计算，除非计算参数本身发生变化。

## 主题预设

`.themed(_:)` 把预设包装为完整外观。包内提供两个预设：`.solaris` 面向浅色方案，`.midnight` 面向深色方案。

`ChartAppearance.ThemePreset` 携带外观值，不含数据行为：

```swift
import UIKit
import SwiftKLine

let preset = ChartAppearance.ThemePreset(
    candleStyle: CandleStyle(risingColor: .systemGreen, fallingColor: .systemRed),
    legendFont: .monospacedDigitSystemFont(ofSize: 11, weight: .regular),
    watermarkText: nil,
    indicatorStyles: [
        .ma(period: 5): LineStyle(strokeColor: .systemOrange)
    ]
)
let appearance = ChartAppearance.themed(preset)
```

- `indicatorStyles: nil` 保留内置默认样式表；显式传入的字典会整体替换默认字典。
- 预设颜色是普通 `UIColor`。`.label` 等动态系统色会跟随深色模式；图表在外观特征变化时会失效图例并重绘。
- 主题不负责选择指标、设置数据源或开启功能；这些都在配置中。

## 蜡烛样式

`CandleStyle` 控制涨跌颜色与初始的蜡烛几何：

| 字段 | 默认值 | 含义 |
|---|---|---|
| `risingColor` | `.systemTeal` | `close` ≥ `open` 的 K 线 |
| `fallingColor` | `.systemPink` | `close` < `open` 的 K 线 |
| `width` | `10` | 初始蜡烛主体宽度（pt） |
| `gap` | `2` | 初始主体间距（pt） |

涨跌色同样用于成交量条与最新价标签。双指捏合会在运行时改变蜡烛宽度；配置值是初始宽度。后续配置修改 `width` 或 `gap` 会重新排布逻辑内容宽度。

## 布局

`LayoutMetrics` 存放固定的区块高度（pt）：

| 字段 | 默认值 | 含义 |
|---|---|---|
| `mainChartHeight` | `320` | 主价格面板 |
| `timelineHeight` | `16` | 主图下方的时间轴 |
| `indicatorHeight` | `64` | 每个已选副图指标面板的高度 |

图表固有高度 = 主图 + 时间轴 + 每个已选副图面板；应用自有控件位于该高度之外。只约束宽度，让高度跟随固有尺寸。UIKit 中按固有高度布局；SwiftUI 使用 `.fixedSize(horizontal: false, vertical: true)`。

## 图例与水印

| 字段 | 默认值 | 含义 |
|---|---|---|
| `legendFont` | 10 pt 等宽数字 | 所有指标图例字体 |
| `watermarkText` | `"Created by iyabb"` | 主图背后的水印文字；置 `nil` 移除 |

图例按面板缓存，由数据、配置或显式重绘请求失效；仅滚动不会重建图例文本。

## 指标样式

指标样式按完整 `SeriesKey` 查找，key 包含全部计算参数。因此同一图表中不同周期的两个 MA 可以有不同颜色。

| 样式 | 适用 |
|---|---|
| `LineStyle(strokeColor:)` | 标量线：MA/EMA/WMA/BBI/SAR/VWMA、BOLL 通道、Donchian 通道、RSI/CCI/WR/ATR/OBV/ROC/MFI/TRIX |
| `KDJStyle(kColor:dColor:jColor:)` | KDJ |
| `DMIStyle(plusDIColor:minusDIColor:adxColor:)` | DMI |

目前公开的样式类型只有上述三种。SuperTrend、Ichimoku 与 MACD 的样式类型尚未公开，使用内置默认配色渲染；缺少或不匹配的样式回退到系统 label 颜色。自定义渲染器可通过 `appearance.indicatorStyle(for:type:)` 查询样式。

```swift
import UIKit
import SwiftKLine

let appearance = ChartAppearance(
    candleStyle: CandleStyle(risingColor: .systemGreen, fallingColor: .systemRed, width: 8, gap: 2),
    legendFont: .monospacedDigitSystemFont(ofSize: 11, weight: .regular),
    watermarkText: nil,
    layoutMetrics: LayoutMetrics(
        mainChartHeight: 280,
        timelineHeight: 16,
        indicatorHeight: 60
    ),
    indicatorStyleRegistry: [
        .ma(period: 5): LineStyle(strokeColor: .systemOrange),
        .ma(period: 10): LineStyle(strokeColor: .systemPink),
        .ma(period: 20): LineStyle(strokeColor: .systemTeal)
    ]
)
```

修改样式或参数前需要记住两条规则：

1. 显式 `indicatorStyleRegistry` 会整体替换默认值。请为每个用到的内置 key 提供条目，否则该指标回退为 label 颜色。
2. 按指标覆盖 key 列表与样式设置是两件事；参见指标指南中的[参数](indicators.md#参数)。
