# Built-in indicators

**English** | [简体中文](zh-CN/indicators.md)

[Documentation](README.md) · [Configuration](configuration.md) · [Appearance](appearance.md)

SwiftKLine ships 22 built-in indicators. Each one runs through the same plugin pipeline as application plugins: one calculator per series key and one or more renderers, coordinated by the chart. The built-in ID namespace `builtin.*` is reserved; custom features use an application-specific prefix.

## Catalog

Main-panel overlays draw on the price chart. Sub-panel indicators get one independent lower panel each; multiple parameter sets of the same sub-panel indicator share that panel.

| Indicator | Panel | Default series keys | Output |
|---|---|---|---|
| MA | Main | `.ma(period:)` 5, 10, 20 | `Double` |
| EMA | Main | `.ema(period:)` 5, 10, 20 | `Double` |
| WMA | Main | `.wma(period:)` 5, 10, 20 | `Double` |
| BOLL | Main | `.boll(period: 20, k: 2.0)` | `BOLLIndicatorValue` (middle/upper/lower) |
| SAR | Main | `.sar` (af 0.02 / 0.02 / 0.2) | `Double` |
| BBI | Main | `.bbi` (periods 3, 6, 12, 24) | `Double` |
| VWMA | Main | `.vwma(period: 20)` | `Double` |
| Donchian | Main | `.donchian(period: 20)` | `BandIndicatorValue` (upper/middle/lower) |
| SUPER (SuperTrend) | Main | `.superTrend(period: 10, multiplier: 3)` | directional trailing line |
| ICHI (Ichimoku) | Main | `.ichimoku(9, 26, 52, 26)` | five-line overlay with cloud |
| VOL | Sub | `.vol` | direction-colored volume |
| RSI | Sub | `.rsi(period:)` 6, 12, 24 | `Double` |
| MACD | Sub | `.macd(short: 12, long: 26, signal: 9)` | `MACDIndicatorValue` (macd/signal/histogram) |
| KDJ | Sub | `.kdj(period: 9, kPeriod: 3, dPeriod: 3)` | `KDJIndicatorValue` (K/D/J) |
| CCI | Sub | `.cci(period: 20)` | `Double` |
| WR | Sub | `.wr(period: 14)` | `Double` (−100…0 scale) |
| DMI | Sub | `.dmi(diPeriod: 14, adxPeriod: 14)` | `DMIIndicatorValue` (+DI/−DI/ADX) |
| ATR | Sub | `.atr(period: 14)` | `Double` |
| OBV | Sub | `.obv` | `Double`, cumulative |
| ROC | Sub | `.roc(period: 9)` | `Double`, percent |
| MFI | Sub | `.mfi(period: 14)` | `Double` |
| TRIX | Sub | `.trix(period: 18)` | `Double`, percent |

The `BuiltInIndicator` enum lists these cases (`.superTrend` and `.ichimoku` use the short titles `SUPER` and `ICHI`). `IndicatorID` exposes stable open IDs such as `builtin.ma` for selection, persistence, and plugin replacement.

## Selection

The selector is the built-in UI for choosing indicators. UIKit exposes `indicatorSelection`, `setIndicators(_:)`, and `resetIndicatorsToDefault()`; SwiftUI binds a selection state directly.

| Equivalent API | Result |
|---|---|
| `configuration.indicators` set to a new value | Replaces the current selection |
| `configuration.indicators` set to `nil` | Restores current appearance defaults |
| The value stays unchanged | Keeps user selection, including across source changes |
| Appearance defaults change | Does not reset the current selection |
| `setIndicators(_:)` / `resetIndicatorsToDefault()` | Explicit imperative commands |

### Initial state

The initial selection uses the first applicable source, then filters invalid, duplicate, unavailable, or wrong-panel IDs:

| Priority | Source | Condition |
|---|---|---|
| 1 | Persisted selection | Persistence is enabled and the store contains a nonempty selection |
| 2 | `configuration.indicators` | Provided explicitly |
| 3 | Appearance defaults | Neither of the above supplied a selection |

If a persisted selection normalizes to empty, the chart keeps that empty result and does not fall back to configuration or defaults.

### Persistence

When `.indicatorPersistence` is enabled (part of `features: .all`), selection is read at chart creation and saved after initial normalization and after selector, set, or reset commands. Applying a configuration alone never saves the processed selection. Enabling persistence on an existing chart does not re-read storage.

The default `UserDefaultsIndicatorSelectionStore` shares one key across data sources and charts. UIKit can inject a store with a different key to isolate charts; `KLineChart` does not provide store injection — apps that store the selection themselves can disable built-in persistence and manage the selection through the binding.

## Parameters

Default parameters live in the default series keys above. To run custom periods through the same selection and rendering, override the key list per indicator:

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

Rules the chart applies to overrides:

- A key whose parameters cannot be parsed or does not match its indicator is skipped, not guessed.
- Custom parameter keys need their own style entries; see [indicator styles](appearance.md#indicator-styles).
- Parameter changes rerun calculation for the affected series and reuse renderers only when the key set is unchanged.

## Reference lines

Sub-panel indicators draw fixed reference levels: 20 and 80 for KDJ/MFI, −80 and −20 for WR, −100/0/100 for CCI, 20 and 25 for DMI, and 0 for ROC/TRIX. The KDJ axis includes J values beyond 0…100; the ATR axis includes zero; OBV scales to the visible values. Missing or non-finite values break the path; legends follow the selected or last visible candle.

## Calculators in Core

`SwiftKLineCore` exports the calculator implementations, so headless or cross-platform calculations work without UIKit:

| Calculator | Output values |
|---|---|
| `MACalculator(period:)`, `EMACalculator`, `WMACalculator`, `VWMACalculator` | `Double` |
| `BOLLCalculator(period:k:)`, `DonchianCalculator` | `BandIndicatorValue` |
| `SARCalculator`, `BBICalculator(periods:)` | `Double` |
| `SuperTrendCalculator(period:multiplier:)`, `IchimokuCalculator` | typed overlay values |
| `RSICalculator`, `CCICalculator`, `WRCalculator`, `ATRCalculator`, `ROCCalculator` | `Double` |
| `KDJCalculator(period:kPeriod:dPeriod:)`, `DMICalculator(diPeriod:adxPeriod:)` | typed tuples |
| `MACDCalculator(shortPeriod:longPeriod:signalPeriod:)` | `MACDIndicatorValue` |
| `VOLCalculator`, `OBVCalculator`, `MFICalculator`, `TRIXCalculator` | `Double` |

```swift
import SwiftKLineCore

func macdBars(from candles: [any ChartItem]) -> [MACDIndicatorValue?] {
    MACDCalculator(shortPeriod: 12, longPeriod: 26, signalPeriod: 9)
        .calculate(for: candles)
}
```

Output contracts shared by all calculators:

- One optional output per input candle, in input order; warm-up positions are `nil`.
- Nonpositive periods return aligned `nil` output instead of throwing.
- `calculate(for:)` never mutates or sorts the input.
- `update(for:values:from:)` recomputes the whole array by default; implementations may provide cheaper suffix paths when the unchanged prefix and parameters stay valid.
- Mixing suffix updates with a reused previous output requires the same calculator semantics; source replacement, prepended history, or parameter changes must restart from index 0.

To run multiple series coherently, pass `AnyIndicatorCalculator` wrappers to `IndicatorEngine.calculate(items:calculators:previous:invalidatedFrom:)`. The engine runs calculators in structured child tasks, and merges duplicate keys deterministically by declaration order (the last one wins), independent of task completion order.

## Formula references

KDJ, CCI, DMI, ATR, OBV, MFI, and TRIX follow public definitions collected at:

[KDJ](https://support.futunn.com/topic149), [CCI](https://www.tradingview.com/support/solutions/43000502001-commodity-channel-index-cci/), [DMI](https://www.tradingview.com/support/solutions/43000502250-directional-movement-dmi/), [ATR](https://www.tradingview.com/support/solutions/43000501823-average-true-range-atr/), [OBV](https://www.tradingview.com/support/solutions/43000502593-on-balance-volume-obv/), [MFI](https://www.tradingview.com/support/solutions/43000502348-money-flow-mfi/), [TRIX](https://www.tradingview.com/support/solutions/43000502331-trix/)

The conventions pin the initialization behavior of this library; they do not promise point-identical output across platforms or different history starting points.
