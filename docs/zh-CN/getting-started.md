# 快速开始

[English](../getting-started.md) | **简体中文**

[文档索引](README.md)

本页带你从空项目走到渲染出图表。全部内容使用 `SwiftKLine` 产品；两个 UI 框架使用同一套 API。

## 环境要求

| 组件 | 要求 |
|---|---|
| 图表库 | iOS / iPadOS 13.0+ |
| 工具链 | Swift 6.0+,Xcode 16+ |
| 图表渲染 | 基于 UIKit；可从 SwiftUI 使用 |
| Core 库 | 仅依赖 Foundation；同时构建于 macOS 10.15+ |

仓库当前使用 Xcode 26.2 验证。SwiftKLine 没有第三方包依赖。

## 1. 添加依赖

在 Xcode 中选择 **File → Add Package Dependencies**，输入：

```text
https://github.com/zhwayne/SwiftKLine.git
```

将 **SwiftKLine** 产品添加到应用 target。在 `Package.swift` 中使用：

```swift
.package(url: "https://github.com/zhwayne/SwiftKLine.git", branch: "main"),
.product(name: "SwiftKLine", package: "SwiftKLine")
```

当前仓库没有发布标签。使用 `main` 跟踪开发进度；需要可复现构建时，通过 `revision:` 固定已审查的提交。如果只需要数据工具与指标计算，选择 **SwiftKLineCore** 产品并 `import SwiftKLineCore` — 见[内置指标](indicators.md#在-core-中直接使用计算器)。

## 2. 构建配置

图表显示的所有内容都来自一个经过校验的 `ChartConfiguration` 值。下面的示例从离线快照生成静态图表。时间戳是 K 线开盘时间的 Unix **秒**；配置请在主 actor 上创建。

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

关于这段代码：

- `features: []` 关闭实时更新和缺口恢复，适合静态图表。实时行情图表使用默认的 `.all`。
- 空数据源 ID 或空/重复插件 ID 会使构造失败。请在应用初始化边界处理该错误。
- 构造图表时通过 `ChartSelection` 提供周期与指标初值；动态选择与持久化见[内置指标](indicators.md)。

## 3. 显示图表

### SwiftUI

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

`.fixedSize(horizontal: false, vertical: true)` 让图表使用配置面板决定的固有高度；应用控件组合在图表之外。

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

图表自带固有高度。只需约束宽度；高度由 `appearance.layoutMetrics` 和已选副图面板决定。后续变更使用 `chart.apply(configuration)`。

## 4. 你得到什么

按上述配置，图表会显示：

- 支持滚动、双指缩放，以及点按/长按十字光标与图例的蜡烛图主图。
- 已选的 MA 叠加线、VOL 与 MACD 副图面板。示例应用在图表下方组合自有指标选择器。
- 十字光标选中 K 线时更新的数值图例；`scrollToLatest()` 与点击返回最新始终可用。

改变外观见[外观定制](appearance.md)；改变行为见[配置与集成](configuration.md)。

## 5. 下一步：接入真实行情

`SnapshotProvider` 捕获固定数组并立即结束分页。持续更新的数据需要自行实现 `ChartItemProvider`：历史分页、可选的完整 K 线快照实时流，以及可选的恢复区间。[数据源指南](data-providers.md)解释该契约；[完整网络示例](../../SwiftKLineExample/BinanceDataProvider.swift)展示了 HTTP 历史 + WebSocket 实时流的实现。

## 手势与快捷操作

| 手势 | 效果 |
|---|---|
| 平移 | 滚动历史；接近左边缘时请求更早页 |
| 双指捏合 | 改变蜡烛宽度，保持手势锚点 |
| 点按或长按 | 在对应 K 线上显示十字光标与图例 |
| 系统回到顶部（点状态栏） | 滚动到最新 K 线 |
