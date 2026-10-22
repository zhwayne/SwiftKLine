# Changelog

**English** | [简体中文](CHANGELOG.zh-CN.md)

Notable changes are grouped below. `Unreleased` describes the current development tree and is not a published release. Dated sections are development milestones from Git history, not version tags. The current repository has no release tags.

## Unreleased

### Added

- Built-in BBI, VWMA, and Donchian main-chart indicators, with reusable channel rendering and parameter-aware series keys.
- Built-in SuperTrend (SUPER) and Ichimoku (ICHI) main-chart indicators, with directional SuperTrend ribbons and flip breaks, and a five-line cloud overlay.
- A shared `ChartConfiguration` API for UIKit and SwiftUI, with `CandleSource`, `ChartAppearance`, content mode, plugins, selection, and feature flags.
- A `ChartPlugin` lifecycle with per-chart coordinators, scoped resource registration, isolated series, error reporting, and redraw requests.
- Independent time-range pagination through `RangeDataProvider`, `RangePage`, and `RangeLoader`, including coverage, retry, cancellation, and bounded caches.
- An application-owned trade-marker example with provider, plugin, rendering, and regression coverage.
- Complete English and Simplified Chinese documentation, page-to-page language switches, a documentation index, a contribution guide, and a changelog.

### Changed

- Built-in indicators use the plugin pipeline while retaining selector, persistence, appearance, and layout behavior.
- Candles and their indicator outputs publish as a consistent batch; independent external data does not delay that publication.
- History and configuration invalidation preempt the coalesced live timer.
- Resource namespaces allow multiple instances of a feature in one chart.
- Documentation onboarding now links a complete network provider, explains selection precedence with decision tables, and runs bilingual link and snippet validation in CI.

### Fixed

- Corrected documentation for merge precedence, recovery and retry limits, selector persistence, plugin IDs, range-loader notifications, and benchmark scope.
- Viewport and scene input no longer invalidate the legend cache on every dispatch.
- Time-series caches detect revisions to interior candles.
- Cancelled calculation tasks no longer consume the next refresh's scheduling state.

## 2026-10-21

### Changed

- Split the library into Core, UIKit, SwiftUI, and umbrella targets; optimized indicator calculation and drawing; removed the third-party layout dependency ([c017603](https://github.com/zhwayne/SwiftKLine/commit/c017603)).

### Fixed

- Prevented stale chart updates and cleaned up live subscriptions ([982f2b2](https://github.com/zhwayne/SwiftKLine/commit/982f2b2)).

## 2026-05-17

### Changed

- Narrowed public APIs, renamed indicator types, and removed legacy code ([e94f5be](https://github.com/zhwayne/SwiftKLine/commit/e94f5be), [fcbc1cb](https://github.com/zhwayne/SwiftKLine/commit/fcbc1cb)).
- Renamed KLine concepts to Chart concepts and redesigned configuration ([b9ea9d6](https://github.com/zhwayne/SwiftKLine/commit/b9ea9d6)).
- Removed obsolete repository artifacts ([75b9ec7](https://github.com/zhwayne/SwiftKLine/commit/75b9ec7)).

## 2026-05-13

### Added

- Configurable MACD and BOLL parameters ([56fe301](https://github.com/zhwayne/SwiftKLine/commit/56fe301)).

### Fixed

- Loader error handling and unsafe force unwraps ([72d539e](https://github.com/zhwayne/SwiftKLine/commit/72d539e)).

## 2026-04-27

### Changed

- Extracted the data-loading actor ([c873a87](https://github.com/zhwayne/SwiftKLine/commit/c873a87)), calculation engine ([bbe5137](https://github.com/zhwayne/SwiftKLine/commit/bbe5137)), and rendering coordinators ([19b756e](https://github.com/zhwayne/SwiftKLine/commit/19b756e)).
- Updated usage documentation ([5b1d68b](https://github.com/zhwayne/SwiftKLine/commit/5b1d68b)).

## 2026-02

### Changed

- Refactored the indicator pipeline and centralized specifications ([0afc4fa](https://github.com/zhwayne/SwiftKLine/commit/0afc4fa)).

### Fixed

- Pagination exhaustion and duplicate historical pages ([a039157](https://github.com/zhwayne/SwiftKLine/commit/a039157)).

## 2025-12

### Changed

- Reduced redraw costs ([e526a27](https://github.com/zhwayne/SwiftKLine/commit/e526a27)) and simplified rendering calculations and crosshair behavior ([e5df64e](https://github.com/zhwayne/SwiftKLine/commit/e5df64e)).

### Fixed

- Division by zero in change-rate and amplitude calculations ([5bbad40](https://github.com/zhwayne/SwiftKLine/commit/5bbad40)).

## 2025-11

### Added

- WMA calculation and rendering ([1a2c947](https://github.com/zhwayne/SwiftKLine/commit/1a2c947)).
- Bucket duration management ([334e411](https://github.com/zhwayne/SwiftKLine/commit/334e411)).
- Persistent indicator selection ([85ce67e](https://github.com/zhwayne/SwiftKLine/commit/85ce67e)) and custom renderer management ([2f19fb5](https://github.com/zhwayne/SwiftKLine/commit/2f19fb5)).

### Fixed

- Price labels follow current layout bounds ([d043492](https://github.com/zhwayne/SwiftKLine/commit/d043492)).

## 2025-04

### Added

- MACD rendering ([ec4eff8](https://github.com/zhwayne/SwiftKLine/commit/ec4eff8)), a Binance provider example ([69cdba7](https://github.com/zhwayne/SwiftKLine/commit/69cdba7)), and period switching ([d914653](https://github.com/zhwayne/SwiftKLine/commit/d914653)).

### Changed

- Introduced the historical `KLineItemProvider` API ([6470b7e](https://github.com/zhwayne/SwiftKLine/commit/6470b7e)) and reorganized source layout ([a8832d7](https://github.com/zhwayne/SwiftKLine/commit/a8832d7)). Use [current guides](docs/README.md) for today's API names.
