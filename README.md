# SwiftKLine

**English** | [简体中文](README.zh-CN.md)

A modular candlestick chart library for iOS and iPadOS, built with Swift, UIKit, and Core Animation. Use the same configuration in UIKit and SwiftUI.

[![Swift 6](https://img.shields.io/badge/Swift-6.0%2B-orange)](Package.swift)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20iPadOS-blue)](#requirements)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen)](#installation)
[![MIT License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

<p align="center">
  <a href="docs/assets/chart-preview.png">
    <img src="docs/assets/chart-preview.png" alt="SwiftKLine showing candlesticks, moving averages, volume, MACD, and the indicator selector" width="520">
  </a>
  <br>
  <sub>Offline quick-start result. Open the image for the full-size chart.</sub>
</p>

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Example app](#example-app)
- [Documentation](#documentation)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

## Features

- Candlestick and time-series charts with scrolling, pinch zoom, and a crosshair.
- Built-in MA, EMA, WMA, BOLL, SAR, BBI, VWMA, Donchian, SuperTrend (SUPER), Ichimoku (ICHI), VOL, RSI, MACD, KDJ, CCI, WR, DMI, ATR, OBV, ROC, MFI, and TRIX indicators, with open selection state and pluggable persistence.
- Historical pagination, complete live candle snapshots, and optional gap recovery.
- Shared `ChartConfiguration` for UIKit and SwiftUI, with light and dark theme presets.
- Custom indicators, overlays, and sub-panels through `ChartPlugin`.
- Independent time-range pagination for application data through `RangeDataProvider` and `RangeLoader`.
- Visible-range drawing, reusable layers, incremental calculation where supported, and coalesced live updates.
- No third-party package dependencies.

## Requirements

| Component | Requirement |
|---|---|
| Chart library | iOS / iPadOS 13.0+ |
| Toolchain | Swift 6.0+; Xcode 16+ |
| Core library | Foundation only; also supports macOS 10.15+ |
| Example app | iOS / iPadOS 18.0+ |

Repository development checks currently use Xcode 26.2. The macOS platform in the package manifest supports Core usage and host tests; chart rendering requires UIKit.

## Installation

In Xcode, select **File → Add Package Dependencies**, enter the repository URL, and add the **SwiftKLine** product to your app target:

```text
https://github.com/zhwayne/SwiftKLine.git
```

For a Swift package, add the dependency and product to the corresponding arrays in `Package.swift`:

```swift
.package(url: "https://github.com/zhwayne/SwiftKLine.git", branch: "main")
```

```swift
.product(name: "SwiftKLine", package: "SwiftKLine")
```

There are no release tags in the current repository. Use `main` to follow development, or pin a reviewed commit with `revision:` for reproducible builds. For data utilities and calculations without chart rendering, select the **SwiftKLineCore** product and `import SwiftKLineCore`.

## Quick start

### Create a configuration

This example uses a finite, offline snapshot. Timestamps are candle-open Unix times in **seconds**. Create configurations and charts on the main actor.

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

This produces the light, offline chart shown above. `features: []` disables live updates and gap recovery for this static example. Handle configuration errors at your app's setup boundary; construction rejects empty source IDs and empty or duplicate plugin IDs.

### SwiftUI

Pass the configuration returned above into your view:

```swift
import SwiftUI
import SwiftKLine

@MainActor
struct MarketChart: View {
    let configuration: ChartConfiguration
    @State private var selection = ChartSelection(period: .oneMinute,
        indicators: IndicatorSelection(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol, .macd]))

    var body: some View {
        KLineChart(selection: $selection) { _ in configuration }
            .fixedSize(horizontal: false, vertical: true)
    }
}
```

Keep dynamic configuration in your application model and pass updated values to the view. The adapter applies updates and ends its sessions when removed.

### UIKit

```swift
import UIKit
import SwiftKLine

@MainActor
func installChart(in container: UIView, configuration: ChartConfiguration) -> ChartView {
    let selection = ChartSelection(period: .oneMinute,
        indicators: IndicatorSelection(mainIndicatorIDs: [.ma], subIndicatorIDs: [.vol, .macd]))
    let chart = ChartView(configuration: configuration, selection: selection)
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

The chart supplies an intrinsic height for its main, time-axis, and selected sub-panels. Apply later changes with `chart.apply(configuration)`.

A stable `CandleSource.id` retains the provider session while `.liveUpdates` and `.gapRecovery` remain unchanged. Change it when the symbol, period, market calendar, or snapshot changes. Replacing a provider factory alone does not refresh a session with the same ID. For a network feed, implement `ChartItemProvider` and see the [data provider guide](docs/data-providers.md).

## Example app

Open [SwiftKLineExample.xcodeproj](SwiftKLineExample.xcodeproj) in Xcode, select the `SwiftKLineExample` scheme, and run on an iOS 18+ simulator or device.

The app demonstrates period switching, candlestick and time-series presentation, and an application-owned SwiftUI indicator selector. Both selectors bind to one `ChartSelection`; the library restores and persists it through `ChartStateStore`. Normal runs use the example's Binance provider and require network access to that service. The standalone chart preview uses deterministic offline data.

The optional [trade-marker example](SwiftKLineExample/TradeMarkers/TradeMarkerExample.swift) demonstrates an application-owned provider, plugin, and renderer with separate pagination. It is not enabled on the default page. Its trade types and account/query identities belong to the example, not the public library API.

## Documentation

The [documentation index](docs/README.md) provides reading paths and links to the Chinese edition.

| Guide | Topics |
|---|---|
| [Getting started](docs/getting-started.md) | Install, build a configuration, and render a chart in SwiftUI and UIKit |
| [Configuration](docs/configuration.md) | Fields, update semantics, features, errors, and the chart API |
| [Data providers](docs/data-providers.md) | Candle feeds, paging, live snapshots, recovery, time boundaries, and range data |
| [Indicators](docs/indicators.md) | Built-in catalog, shared state stores, selection, parameters, and Core calculators |
| [Appearance](docs/appearance.md) | Themes, candle style, layout, legend, and series styles |
| [Plugins](docs/plugins.md) | Custom indicators, overlays, panels, and lifecycle cleanup |
| [Architecture](docs/architecture.md) | Modules, ownership, concurrency, and rendering |
| [Performance](docs/performance.md) | Runtime costs, benchmarks, and measurement |

## Development

```sh
swift test
./script/test-ios.sh
./script/build-example.sh
./script/validate-docs.py
```

Host tests exercise Foundation code. The iOS test script runs the package tests on an available iPhone simulator. The documentation check validates local links, heading anchors, language counterparts, and matching executable snippets. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, command overrides, and pull request guidance.

## Contributing

Bug reports, focused pull requests, examples, and translations are welcome. Read the [contribution guide](CONTRIBUTING.md) before submitting changes. Use [GitHub Issues](https://github.com/zhwayne/SwiftKLine/issues) for reproducible bugs and feature proposals, and check the [changelog](CHANGELOG.md) for development changes.

## License

Released under the [MIT License](LICENSE).
