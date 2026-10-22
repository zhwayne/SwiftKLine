# SwiftKLine

[English](README.md) | **简体中文**

面向 iOS 和 iPadOS 的模块化 K 线图表库，使用 Swift、UIKit 和 Core Animation 构建。UIKit 与 SwiftUI 共用同一套配置。

[![Swift 6](https://img.shields.io/badge/Swift-6.0%2B-orange)](Package.swift)
[![支持平台](https://img.shields.io/badge/platforms-iOS%20%7C%20iPadOS-blue)](#环境要求)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen)](#安装)
[![MIT 许可证](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

<p align="center">
  <a href="docs/assets/chart-preview.png">
    <img src="docs/assets/chart-preview.png" alt="SwiftKLine 的蜡烛图、均线、成交量、MACD 和指标选择器" width="520">
  </a>
  <br>
  <sub>离线快速开始的运行结果；点击图片可查看完整尺寸。</sub>
</p>

## 目录

- [功能](#功能)
- [环境要求](#环境要求)
- [安装](#安装)
- [快速开始](#快速开始)
- [示例应用](#示例应用)
- [文档](#文档)
- [开发与验证](#开发与验证)
- [参与贡献](#参与贡献)
- [许可证](#许可证)

## 功能

- 蜡烛图与分时折线图，支持滚动、双指缩放和十字光标。
- 内置 MA、EMA、WMA、BOLL、SAR、BBI、VWMA、Donchian、SuperTrend（SUPER）、Ichimoku（ICHI）、VOL、RSI、MACD、KDJ、CCI、WR、DMI、ATR、OBV、ROC、MFI、TRIX，提供指标选择器与可选的选择状态持久化。
- 历史数据分页、完整实时 K 线快照与可选的缺口恢复。
- UIKit 与 SwiftUI 共用 `ChartConfiguration`，提供明暗主题预设。
- 通过 `ChartPlugin` 扩展指标、叠加层与副图。
- 通过 `RangeDataProvider` 和 `RangeLoader` 为业务数据独立进行时间范围分页。
- 按可见范围绘制、复用图层，在支持的计算路径上增量更新，并合并高频实时更新。
- 无第三方包依赖。

## 环境要求

| 组件 | 要求 |
|---|---|
| 图表库 | iOS / iPadOS 13.0+ |
| 工具链 | Swift 6.0+；Xcode 16+ |
| Core 库 | 仅依赖 Foundation，同时支持 macOS 10.15+ |
| 示例应用 | iOS / iPadOS 18.0+ |

仓库当前使用 Xcode 26.2 进行开发验证。包清单中的 macOS 支持用于 Core 使用和宿主机测试；图表渲染需要 UIKit。

## 安装

在 Xcode 中选择 **File → Add Package Dependencies**，输入仓库地址，将 **SwiftKLine** 产品添加到应用 target：

```text
https://github.com/zhwayne/SwiftKLine.git
```

如果使用 Swift 包，在 `Package.swift` 对应的依赖和产品数组中添加：

```swift
.package(url: "https://github.com/zhwayne/SwiftKLine.git", branch: "main")
```

```swift
.product(name: "SwiftKLine", package: "SwiftKLine")
```

当前仓库没有发布标签。使用 `main` 跟踪开发进度；需要可复现构建时，通过 `revision:` 固定已审查的提交。如果只需要数据工具与指标计算，选择 **SwiftKLineCore** 产品，并使用 `import SwiftKLineCore`。

## 快速开始

### 创建配置

以下示例使用有限的离线快照。时间戳为 K 线开盘时间，单位是 Unix **秒**。配置与图表均在主 actor 上创建。

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
        indicators: IndicatorSelectionState(
            mainIndicatorIDs: [.ma],
            subIndicatorIDs: [.vol, .macd]
        ),
        features: []
    )
}
```

运行后会得到上图所示的明亮主题离线图表。`features: []` 为此静态示例关闭实时更新、缺口恢复和指标持久化。请在应用初始化边界处理配置错误；空数据源 ID、空插件 ID 或重复插件 ID 会使构造失败。

### SwiftUI

将上面返回的配置传入视图：

```swift
import SwiftUI
import SwiftKLine

@MainActor
struct MarketChart: View {
    let configuration: ChartConfiguration

    var body: some View {
        KLineChart(configuration: configuration)
            .fixedSize(horizontal: false, vertical: true)
    }
}
```

将动态配置保存在应用模型中，并向视图传递更新后的值。适配器负责应用更新，并在视图移除时结束会话。

### UIKit

```swift
import UIKit
import SwiftKLine

@MainActor
func installChart(in container: UIView, configuration: ChartConfiguration) -> ChartView {
    let chart = ChartView(configuration: configuration)
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

图表会根据面板和选择器提供固有高度。后续使用 `chart.apply(configuration)` 应用配置变更。

当 `.liveUpdates` 和 `.gapRecovery` 不变时，稳定的 `CandleSource.id` 会保留 provider 会话。当交易对、周期、市场日历或快照变化时，应更换 ID。仅替换 provider 工厂闭包不会刷新相同 ID 的会话。接入网络行情时，实现 `ChartItemProvider` 并启用所需的[加载能力](docs/zh-CN/configuration.md#加载与错误)。

## 示例应用

在 Xcode 中打开 [SwiftKLineExample.xcodeproj](SwiftKLineExample.xcodeproj)，选择 `SwiftKLineExample` scheme，在 iOS 18+ 模拟器或设备上运行。

应用演示周期切换、蜡烛图与分时图切换、指标选择器。正常运行使用示例中的 Binance provider，需要能够访问该服务；SwiftUI 预览使用确定性的离线数据。

可选的[成交标记示例](SwiftKLineExample/TradeMarkers/TradeMarkerExample.swift) 演示应用自有的 provider、插件和渲染器，以及独立分页。默认页面未启用该插件。成交模型与账户或查询身份属于示例代码，不是库的公开 API。

## 文档

[文档索引](docs/zh-CN/README.md) 提供阅读路径，并可切换到英文版。

| 指南 | 内容 |
|---|---|
| [配置与集成](docs/zh-CN/configuration.md) | 接入、稳定标识、外观、指标选择和错误处理 |
| [数据源与分页](docs/zh-CN/data-providers.md) | 行情数据、时间边界、分页、重试和缓存 |
| [插件与自定义图表](docs/zh-CN/plugins.md) | 自定义指标、叠加层、副图和生命周期清理 |
| [架构与所有权](docs/zh-CN/architecture.md) | 模块、状态归属、并发和渲染 |
| [性能与测量](docs/zh-CN/performance.md) | 运行成本、基准测试和测量方法 |

## 开发与验证

```sh
swift test
./script/test-ios.sh
./script/build-example.sh
./script/validate-docs.py
```

宿主机测试验证 Foundation 代码；iOS 测试脚本在可用的 iPhone 模拟器上运行包测试。文档检查会验证本地链接、标题锚点、双语对应关系及可执行片段的一致性。环境准备、命令覆盖与 PR 要求见[贡献指南](CONTRIBUTING.zh-CN.md)。

## 参与贡献

欢迎提交问题报告、聚焦的 PR、示例与翻译。提交前请阅读[贡献指南](CONTRIBUTING.zh-CN.md)。可复现缺陷与功能建议请提交到 [GitHub Issues](https://github.com/zhwayne/SwiftKLine/issues)；开发变更见[变更记录](CHANGELOG.zh-CN.md)。

## 许可证

项目采用 [MIT 许可证](LICENSE)。
