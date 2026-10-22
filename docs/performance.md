# Performance and measurement

**English** | [简体中文](zh-CN/performance.md)

[Documentation](README.md) · [Architecture](architecture.md)

Measure loading, calculation, main-thread drawing, and system presentation separately. Algorithmic complexity and calculation benchmarks describe part of the pipeline; device frame rate requires device measurement.

## Scheduling behavior

Live snapshots are coalesced over **200 ms** by default. New ticks received during calculation enter the next batch. History pages, recovery, and configuration invalidation request immediate work and can preempt a live timer that has not started.

Structured tasks compute indicators from immutable input, then publish results with the corresponding candles. A changed calculation set can require a full batch. External-data updates and `requestRedraw()` do not trigger indicator calculation.

The legend cache invalidates on data, configuration, resource changes, or explicit redraw requests. Viewport and scene input alone do not invalidate it. Built-in indicator adapters process configuration; application plugins can inspect the full published input.

## Calculation and storage costs

| Operation | Cost | Scope |
|---|---|---|
| Ordered history merge | O(n + m) | Unordered input requires sorting |
| Live tail lookup | O(1) comparisons | Array mutation can still copy storage |
| Interior lookup | O(log n) comparisons | Interior insertion moves O(n) elements |
| Full MA / WMA / BOLL | O(n) | BOLL periodically rebuilds statistics for numerical stability |
| MA / WMA / BOLL suffix update | O(period + changedCount) | Excludes output-array copying |
| EMA / VOL suffix update | O(changedCount) | Excludes output-array copying |
| RSI / MACD / SAR | O(n) | Full calculation path |
| Built-in full draw | O(visibleCount × seriesCount) | Add legends, grid, formatting, and custom-renderer costs |

Suffix costs assume compatible previous outputs and an unchanged prefix; missing seeds, changed keys or parameters, and prepended history can require full calculation.

Raw candles, the published snapshot, outputs, and in-flight calculation inputs coexist. Immutable arrays may share storage until mutation triggers a copy. Enabled indicators, accumulated history, and output types affect memory use; constant-time tail lookup does not make the entire update constant-time.

## Drawing and independent data

The canvas matches the viewport. Renderers reuse layers and iterate visible content. Price paths, legends, and crosshair layers have separate invalidation conditions. Time-series caches use the data revision to detect changes to interior candles.

`RangeLoader` merges pages by ID and sorts cached items for publication. The dominant cost is roughly O(pageItems + cachedItems × log(cachedItems)); eviction also sorts candidates and invalidates coverage. The cache is bounded, but large provider responses still raise peak memory.

The trade-marker example searches sorted events and maps them to real candles in roughly O(log(events) + visibleEvents × log(candles)). Do network work and sorting before rendering.

## Practical guidance

- Keep semantic source and plugin IDs stable so unchanged sessions and resources can be retained.
- Register calculators and renderers only when their relevant parameters change.
- Use `requestRedraw()` for changed external data or renderer styling.
- Remove an unwanted feature from configuration; hiding its drawing alone may leave calculation or loading active.
- Bound page sizes and stream buffers, and size range caches for expected event density.
- Prepare formatting, indexes, and decoded images when inputs change rather than on each draw.

## Run calculation benchmarks

```sh
swift run -c release SwiftKLineBenchmark
swift run -c release SwiftKLineBenchmark 100000
```

The [benchmark](../Benchmarks/main.swift) compares WMA and BOLL window formulas with rolling implementations, and measures a WMA tail update including array-copy costs. The default is 20,000 candles and a fixed period of 200; a positional argument changes the input count, with a minimum of 200. It prints the median of five rounds and a checksum summing each round's returned final value. The checksum is a useful signal, not a replacement for full correctness tests.

When reporting results, record hardware, compiler, optimization level, input count, period, and command. Timings include algorithm and array-copy costs. They do not establish full-chart FPS or peak memory on a device.

## Measure chart interactions

| Scenario | Record |
|---|---|
| First display | Request, decoding, first consistent snapshot, first presentation |
| Period switch | Main-thread work, new-session readiness, reconnection, network wait |
| Indicator switch | Resource coordination, calculation, legend, panel layout |
| Scroll and zoom | Visible count, draw duration, frame intervals, hitches |
| Live feed | Input rate, batch rate, calculation time, publication delay |
| Long run | CPU, memory, cache growth, task and connection release |

Start with fixed offline data and identical indicators, then measure real transport. Warm up and run multiple rounds. Record medians, P95, and spread to distinguish a stable cost from first-use initialization or network variation.

Use Time Profiler for CPU hotspots and Allocations for temporary objects and array copies. Measure frame rate, GPU work, and hitches with appropriate Instruments recordings on a physical device. Report whether the build is Debug or optimized and whether execution uses a simulator or device.

Debug draw-call logs count drawing requests, not screen frames. Keep probes narrow and compare with runs that have no sampler attached.

## Correctness checks

Use the [development commands](../CONTRIBUTING.md#build-and-test) before comparing performance. Core tests cover formulas, suffix equivalence, merge behavior, and numerical boundaries. iOS tests cover publication, plugin isolation, resource reuse, scheduling, and lifecycle; example tests exercise independent data and rendering. Checking documentation links and compiling examples verifies usage, not runtime performance.
