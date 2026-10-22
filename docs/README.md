# Documentation

**English** | [简体中文](zh-CN/README.md)

Start with the [project README](../README.md) to install SwiftKLine and display a chart. These guides describe the API in the current source tree.

## Guides

| Guide | What you will learn |
|---|---|
| [Configuration and integration](configuration.md) | Embed a chart, update configuration, choose indicators, and handle errors |
| [Data providers and pagination](data-providers.md) | Supply candles and independently paginated application data |
| [Plugins and custom charts](plugins.md) | Add calculations, overlays, and sub-panels with per-chart state |
| [Architecture and ownership](architecture.md) | Understand module boundaries, data publication, concurrency, and rendering |
| [Performance and measurement](performance.md) | Understand costs and measure calculations and interactions |

## Suggested reading

- **Integrate a chart:** [Quick start](../README.md#quick-start) → [Configuration](configuration.md) → [Data providers](data-providers.md).
- **Extend the chart:** [Plugins](plugins.md) → [Independent range pagination](data-providers.md#independent-range-pagination) → [Trade-marker example](../SwiftKLineExample/TradeMarkers/TradeMarkerExample.swift).
- **Work on the library:** [Contribution guide](../CONTRIBUTING.md) → [Architecture](architecture.md) → [Performance](performance.md).
- **Review changes:** [Changelog](../CHANGELOG.md).

## Products and targets

| Name | Kind | Responsibility |
|---|---|---|
| `SwiftKLine` | Library product and umbrella target | App-facing imports for Core, UIKit, and SwiftUI on iOS |
| `SwiftKLineCore` | Library product and target | Foundation models, merging, calculators, typed outputs, and range pagination |
| `SwiftKLineUI` | Internal package target | Configuration, lifecycle coordination, UIKit, and Core Animation rendering |
| `SwiftKLineSwiftUI` | Internal package target | `UIViewRepresentable` adapter |

The two products available to package consumers are `SwiftKLine` and `SwiftKLineCore`. The UI targets contain public APIs re-exported by `SwiftKLine`; they are not separate package products.

## Languages and examples

Each documentation page has an **English / 简体中文** switch at the top. The switch opens the equivalent page. Navigation within a guide stays in the chosen language.

English guides live directly in `docs/`; Chinese guides live in `docs/zh-CN/`. Root documents use the `.zh-CN.md` suffix for the Chinese edition. Update both editions when behavior changes. API names and executable examples are the same in both languages; source comments remain in English.

Run `./script/validate-docs.py` from the repository root before submitting a documentation change. It checks local paths, heading links, language counterparts, and equivalent executable snippets. Compile Swift snippets in an iOS app target using the current library. Other build and test commands are in the [contribution guide](../CONTRIBUTING.md#build-and-test).
