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

The application owns period and indicator controls. `ChartConfiguration` describes the source, appearance and plugins; `IndicatorSelection` is a separate input containing built-in choices. The chart consumes values without restoring storage or writing back into application state.

### Initial state

Omitting `indicators:` selects no built-ins. `ChartView.indicators` retains the requested value; `resolvedIndicators` derives recognized, correctly placed, unique built-ins in display order. Applications own default choices and available options. Preserve the original preference and pass `indicators.resolved(availableIndicators: available)` into the chart so temporarily unavailable choices can return later.

Custom plugins are declared in `ChartConfiguration.plugins`. Indicator selection does not toggle custom plugins or explicitly declared built-ins; explicit declarations take precedence when IDs overlap.

### Period configuration

The application validates its period before constructing a source. Include the period and calendar semantics in `CandleSource.id` so changing only indicators preserves the provider. This fixed-duration example supports minute and hour periods; calendar periods need exchange-aware `candleInterval:` rules.

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

SwiftUI integration belongs to the application. First add the example [KLineChart.swift](../SwiftKLineExample/KLineChart.swift) to your app target; the `KLineChart` below is application code and is not exported by the library.

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

An application-owned indicator selector binds to `$indicators`; the chart receives the current value. Period changes rebuild the configuration. The adapter forwards these inputs and performs sizing and teardown, without binding synchronization or persistence tasks.

### UIKit

```swift
import SwiftKLine

@MainActor
func makeChart(period: ChartPeriod, indicators: IndicatorSelection) -> ChartView {
    ChartView(configuration: configuration(for: period), indicators: indicators)
}
```

Use `setIndicators(_:)` to update built-ins, `apply(_:)` to update configuration while retaining requested indicators, or `apply(_:indicators:)` to update both together. To reset, supply application-defined defaults explicitly. Theme changes never select indicators or change their calculation parameters.

### Shared state store

`ChartPreferences`, `ChartStateStore` and migration code belong to the example application and are not exported by the library. Copy the example [Preferences directory](../SwiftKLineExample/Preferences) to reuse them. The application-owned `ChartScreenState` restores and validates once before source construction, retains preferences across view updates, and saves only changed period/indicator values. The App owns this observable instance; ContentView receives it through `@Bindable`. Previews use isolated offline state.

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

`ChartPreferences.restore(from:defaults:)` reads the first decodable record in this order: `chart.preferences`, legacy `chart.selection`, legacy `indicator.selection` combined with the default period, then the supplied defaults. Empty indicators are valid. Restoration does not write or normalize; `save(to:)` writes the current format. JSON and historical property lists are supported.

`UserDefaultsChartStateStore(namespace:)` isolates charts; its default namespace is `com.swiftkline`. `MemoryChartStateStore()` is instance-isolated. Applications may also reuse the Data-backed protocol with typed `ChartStateKey<Value>` values. The application’s `.chartPreferences` key supports explicit removal. Retired legacy records should also be removed if resetting storage must prevent fallback to old preferences.

## Parameters

Default parameters live in the default series keys above. Pass independent calculation settings through `ChartConfiguration.indicatorConfiguration`; `ChartAppearance` holds only visual styles:

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
