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

The `BuiltInIndicator` enum lists these cases (`.superTrend` and `.ichimoku` use the short titles `SUPER` and `ICHI`). `IndicatorID` exposes stable open IDs such as `builtin.ma` for selection, application persistence, and plugin replacement.

## Selection

Period and indicators share one `ChartSelection`, containing `period: ChartPeriod` and `indicators: IndicatorSelection`. Applications supply controls; the library owns restoration, normalization, application and persistence. `ChartConfiguration` contains source and rendering declarations, with no separate selection field.

### Initial state

| Priority | Source | Condition |
|---|---|---|
| 1 | Stored `ChartSelection` | Decodes successfully; empty indicator choices are valid |
| 2 | Legacy indicator record + initial period | No complete stored selection exists |
| 3 | Initial selection / SwiftUI binding | No usable stored record exists |

The static `configuration:` convenience derives a one-minute initial period and appearance-default indicators when no explicit selection is supplied. Use the factory initializer below for period controls.

`availablePeriods` canonicalizes a matching identifier to the supplied period, including its nominal seconds. An unsupported period falls back to the first valid available entry. An empty list accepts custom periods with a nonempty identifier and positive seconds; invalid input uses the initial valid period, or one minute. Indicator IDs are filtered for availability, panel placement and duplicates, retaining order.

### One configuration factory

The library resolves the stored period before constructing configuration and starting a provider. Keep the factory free of side effects and include the period in `CandleSource.id`; changing only indicators then preserves the primary session. This fixed-duration example supports minute and hour periods; calendar periods still need exchange-aware `candleInterval:` rules.

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

An application-owned indicator selector binds to `$selection.indicators`, just as the period picker binds to `$selection.period`. Both use the same chart pipeline; no manual store reads, writes or `.onChange` persistence are needed.

The chart writes restored/normalized selection back asynchronously, outside SwiftUI's update cycle. Later binding edits are commands. A newer user edit takes precedence over an outstanding asynchronous write; unchanged view updates neither save selection again nor restart providers. Availability changes are normalized, persisted and written back too.

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

Read `chart.selection` immediately after construction to populate controls with restored values. Send a whole value through `setSelection(_:)`; `selectionChanged` reports actual changes after normalization and persistence. `resetSelectionToDefault()` restores the initial period and the current appearance's default indicators. To update availability or the factory, use `apply(selection:availablePeriods:configuration:)`; omit selection to preserve current choices.

### Shared state store

`ChartStateStore` is defined and used by the library. It stores the complete `ChartSelection` as one record under an internal key. Pass `nil` to disable persistence, `MemoryChartStateStore()` for an instance-isolated session, or `UserDefaultsChartStateStore(namespace:)` for persistent chart-specific state. The store is fixed for the chart's lifetime; keep its instance/namespace stable.

The default namespace is `com.swiftkline`. Legacy library indicator records are migrated with the supplied initial period. Application-specific legacy keys require application migration. Applications may reuse the same Data-backed protocol and typed `ChartStateKey<Value>` for unrelated preferences; period and indicator selection need no application-defined keys.

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
let selection = IndicatorSelection(subIndicatorIDs: [.kdj, .dmi, .wr])
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
