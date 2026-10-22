# Appearance

**English** | [简体中文](zh-CN/appearance.md)

[Documentation](README.md) · [Indicators](indicators.md) · [Configuration](configuration.md)

All visuals come from `ChartAppearance`, which is part of `ChartConfiguration`. Appearance updates draw immediately and never restart providers or calculations, unless a calculation parameter itself changes.

## Theme presets

`.themed(_:)` wraps a preset into a complete appearance. The package ships two presets: `.solaris` for light color schemes and `.midnight` for dark color schemes.

A `ChartAppearance.ThemePreset` carries appearances, not data behavior:

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

- `indicatorStyles: nil` keeps the built-in default style map; an explicit map replaces the entire default dictionary.
- Preset colors are ordinary `UIColor` values. Dynamic system colors such as `.label` respond to dark mode; the chart invalidates legends and redraws on trait changes.
- The theme does not select indicators, set a data source, or enable features; those come from the configuration.

## Candle style

`CandleStyle` controls rising/falling colors and the initial candle geometry:

| Field | Default | Meaning |
|---|---|---|
| `risingColor` | `.systemTeal` | Candles whose `close` ≥ `open` |
| `fallingColor` | `.systemPink` | Candles whose `close` < `open` |
| `width` | `10` | Initial candle body width in points |
| `gap` | `2` | Initial spacing between bodies in points |

These values also use direction colors for volume bars and the latest-price label. A pinch gesture changes candle width at runtime; the configuration value is the initial width. Changing `width` or `gap` in a later configuration re-lays out the logical content width.

## Layout

`LayoutMetrics` stores fixed section heights in points:

| Field | Default | Meaning |
|---|---|---|
| `mainChartHeight` | `320` | The main price panel |
| `timelineHeight` | `16` | The time axis below the main panel |
| `indicatorHeight` | `64` | Height of each selected sub-panel indicator |
| `indicatorSelectorHeight` | `32` | The built-in selector bar |

The chart's intrinsic height equals the sum of the main panel, the time axis, every selected sub panel, and the selector. Constrain the chart's width only and let the height follow the intrinsic content size. In UIKit check the frame in layout; in SwiftUI use `.fixedSize(horizontal: false, vertical: true)`.

## Legend and watermark

| Field | Default | Meaning |
|---|---|---|
| `legendFont` | 10 pt monospaced-digit | Font for all indicator legends |
| `watermarkText` | `"Created by iyabb"` | Text drawn behind the main chart; `nil` removes it |

The legend is cached per panel and invalidated by data, configuration, or explicit redraw requests; scrolling alone never rebuilds legend text.

## Indicator styles

Indicator styles are looked up by the complete `SeriesKey`, including every calculation parameter. This is why two MA instances with different periods can have different colors in the same chart.

| Style | Used by |
|---|---|
| `LineStyle(strokeColor:)` | Scalar lines: MA/EMA/WMA/BBI/SAR/VWMA, Bollinger bands, Donchian bands, RSI/CCI/WR/ATR/OBV/ROC/MFI/TRIX |
| `KDJStyle(kColor:dColor:jColor:)` | KDJ |
| `DMIStyle(plusDIColor:minusDIColor:adxColor:)` | DMI |

Currently public style types are the three above. SuperTrend, Ichimoku, and MACD keep internal style types; they render with the built-in default colors, and missing or mismatched styles fall back to the system label color. Style lookup for custom renderers is available through `appearance.indicatorStyle(for:type:)`.

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
        indicatorHeight: 60,
        indicatorSelectorHeight: 32
    ),
    indicatorStyleRegistry: [
        .ma(period: 5): LineStyle(strokeColor: .systemOrange),
        .ma(period: 10): LineStyle(strokeColor: .systemPink),
        .ma(period: 20): LineStyle(strokeColor: .systemTeal)
    ]
)
```

Remember two rules before changing styles or keys:

1. An explicit `indicatorStyleRegistry` replaces defaults wholesale. Include entries for every built-in key you use, or that indicator falls back to the label color.
2. Overriding the key list per indicator is separate from styling; see [parameters](indicators.md#parameters) in the indicator guide.
