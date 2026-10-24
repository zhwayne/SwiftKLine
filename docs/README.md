# Documentation

**English** | [简体中文](zh-CN/README.md)

Start with the [project README](../README.md) or the [getting-started guide](getting-started.md) to install SwiftKLine and display a chart. These guides describe the API in the current source tree.

## Guides

| Guide | What you will learn |
|---|---|
| [Getting started](getting-started.md) | Add the package, build a configuration, and render a chart in SwiftUI and UIKit |
| [Configuration and integration](configuration.md) | Configuration fields, update semantics, feature switches, error reporting, and the chart API |
| [Data providers](data-providers.md) | Candle values, the provider contract, history paging, live snapshots, gap recovery, and independent range data |
| [Built-in indicators](indicators.md) | The built-in catalog, shared state stores, selection, parameters, and Core calculators |
| [Appearance](appearance.md) | Themes, candle style, layout metrics, legend and watermark, and series-keyed styles |
| [Plugins and custom charts](plugins.md) | Custom calculations, overlays, and sub panels with per-chart state |
| [Architecture and ownership](architecture.md) | Module boundaries, data publication, concurrency, and rendering (deep dive) |
| [Performance and measurement](performance.md) | Run costs, benchmarks, and measurement methods (deep dive) |

## Suggested reading

- **Integrate a chart:** [Getting started](getting-started.md) → [Configuration](configuration.md) → [Data providers](data-providers.md).
- **Shape built-ins:** [Indicators](indicators.md) → [Appearance](appearance.md).
- **Extend the chart:** [Plugins](plugins.md) → [Independent range pagination](data-providers.md#independent-range-pagination) → [Trade-marker example](../SwiftKLineExample/TradeMarkers/TradeMarkerExample.swift).
- **Work on the library:** [Contribution guide](../CONTRIBUTING.md) → [Architecture](architecture.md) → [Performance](performance.md).
- **Review changes:** [Changelog](../CHANGELOG.md).

## Products and targets

| Name | Kind | Responsibility |
|---|---|---|
| `SwiftKLine` | Library product and umbrella target | App-facing imports for Core and UIKit on iOS |
| `SwiftKLineCore` | Library product and target | Foundation models, merging, calculators, typed outputs, range pagination, and the primary candle-loading session |
| `SwiftKLineUI` | Internal package target | Configuration, lifecycle coordination, UIKit, and Core Animation rendering |

The two products available to package consumers are `SwiftKLine` and `SwiftKLineCore`. The UIKit target contains public APIs re-exported by `SwiftKLine`; it is not a separate package product. SwiftUI bridging belongs to application code; the example supplies a small `UIViewRepresentable` wrapper.

## Languages and examples

Each documentation page has an **English / 简体中文** switch at the top. The switch opens the equivalent page. Navigation within a guide stays in the chosen language.

English guides live directly in `docs/`; Chinese guides live in `docs/zh-CN/`. Root documents use the `.zh-CN.md` suffix for the Chinese edition. Update both editions when behavior changes. API names and executable examples are the same in both languages; source comments remain in English.

Run `./script/validate-docs.py` from the repository root before submitting a documentation change. It checks local paths, heading links, language counterparts, and equivalent executable snippets. Compile Swift snippets in an iOS app target using the current library. Other build and test commands are in the [contribution guide](../CONTRIBUTING.md#build-and-test).
