# Getting started

**English** | [简体中文](zh-CN/getting-started.md)

[Documentation](README.md)

This page takes you from an empty project to a rendered chart. Everything here uses the `SwiftKLine` product; the API names are the same for both UI frameworks.

## Requirements

| Component | Requirement |
|---|---|
| Chart library | iOS / iPadOS 13.0+ |
| Toolchain | Swift 6.0+, Xcode 16+ |
| Chart rendering | UIKit-backed; also usable from SwiftUI |
| Core library | Foundation only; also builds on macOS 10.15+ |

The repository is verified with Xcode 26.2. SwiftKLine has no third-party package dependencies.

## 1. Add the package

In Xcode, choose **File → Add Package Dependencies**, then add:

```text
https://github.com/zhwayne/SwiftKLine.git
```

Add the **SwiftKLine** product to your app target. In a `Package.swift` manifest use:

```swift
.package(url: "https://github.com/zhwayne/SwiftKLine.git", branch: "main"),
.product(name: "SwiftKLine", package: "SwiftKLine")
```

The repository has no release tags. Track `main` for development; pin a reviewed commit with `revision:` when you need reproducible builds. If you only need data tools and indicator calculations, choose the **SwiftKLineCore** product and `import SwiftKLineCore` — see [built-in indicators](indicators.md#calculators-in-core).

## 2. Build a configuration

Everything a chart shows comes from one validated `ChartConfiguration` value. The sample below produces a static chart from an offline snapshot. Timestamps are candle-open Unix time in **seconds**; create configurations on the main actor.

```swift
import SwiftKLine

@MainActor
func sampleConfiguration() throws -> ChartConfiguration {
    let candles = (0..<60).map { index in
        let price = 100 + Double(index) * 0.25
        return Candle(
            timestamp: 1_700_000_040 + index * 60,
            open: price, high: price + 2, low: price - 1,
            close: price + 1, volume: 1_000
        )
    }
    return try ChartConfiguration(
        source: CandleSource(id: "demo:1m:snapshot-v1", duration: 60) {
            SnapshotProvider(items: candles)
        },
        appearance: .themed(.solaris),
        features: []
    )
}
```

Notes on this snippet:

- `features: []` turns off live updates and gap recovery, which is right for a static chart. Real-time charts use the default `.all`.
- Construction throws for an empty source ID or an empty/duplicate plugin ID. Handle this at your app's initialization boundary.
- `IndicatorSelection` supplies built-in indicator choices. Applications own the period and optional application-defined persistence; see [built-in indicators](indicators.md).

## 3. Display it

### SwiftUI

SwiftUI integration belongs to the application. First add the example [KLineChart.swift](../SwiftKLineExample/KLineChart.swift) to your app target; the `KLineChart` below is application code and is not exported by the library.

```swift
import SwiftUI
import SwiftKLine

@MainActor
struct MarketChart: View {
    let configuration: ChartConfiguration
    @State private var indicators = IndicatorSelection(
        mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol, .macd])

    var body: some View {
        KLineChart(configuration: configuration, indicators: indicators)
            .fixedSize(horizontal: false, vertical: true)
    }
}
```

`.fixedSize(horizontal: false, vertical: true)` lets the chart use its intrinsic height from the configured panels. Application controls are composed outside the chart.

### UIKit

```swift
import UIKit
import SwiftKLine

@MainActor
func installChart(in container: UIView, configuration: ChartConfiguration) -> ChartView {
    let indicators = IndicatorSelection(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol, .macd])
    let chart = ChartView(configuration: configuration, indicators: indicators)
    container.addSubview(chart)
    chart.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        chart.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        chart.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        chart.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor)
    ])
    return chart
}
```

The chart supplies its own intrinsic height. Constrain the width only; the height follows `appearance.layoutMetrics` and the selected sub panels. Later changes go through `chart.apply(configuration)`.

## 4. What you get

With the configuration above the chart shows:

- A candlestick main panel with scrolling, pinch zoom, and a tap or long-press crosshair with a legend.
- The selected MA overlay plus VOL and MACD sub panels. The example app composes its own indicator selector below the chart.
- An updated value legend while the crosshair selects candles; `scrollToLatest()` and tap-to-return remain available.

To change looks, see [appearance](appearance.md). To change behavior, see [configuration](configuration.md).

## 5. Next step: real market data

`SnapshotProvider` captures a fixed array and ends pagination immediately. For continuous data, implement `ChartItemProvider` yourself: history pages, an optional live stream of complete candle snapshots, and an optional recovery interval. The [data provider guide](data-providers.md) explains the contract, and the [complete network example](../SwiftKLineExample/BinanceDataProvider.swift) shows a real implementation with HTTP history and a WebSocket live stream.

## Accelerators and gestures

| Gesture | Effect |
|---|---|
| Pan | Scrolls history; near the left edge the chart requests older pages |
| Pinch | Changes candle width, preserving the gesture anchor |
| Tap or long press | Shows the crosshair and legend at that candle |
| iOS scroll-to-top (status-bar tap) | Scrolls to the latest candle |
