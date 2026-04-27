![SwiftKLine](https://socialify.git.ci/zhwayne/SwiftKLine/image?description=1&font=KoHo&forks=1&issues=1&language=1&name=1&owner=1&pattern=Circuit+Board&pulls=1&stargazers=1&theme=Auto)

一个轻量级、模块化且易于扩展的 K 线图表框架，专为 Swift 应用设计。

<img src="https://github.com/user-attachments/assets/efa0309e-72c6-4d2a-8d27-60891d7bfcda" width=50%>

# 功能特点

## 核心架构

- 模块化设计：数据加载、指标计算、渲染协调、交互和样式分层管理。
- 高性能渲染：复用 renderer、缓存 legend、合并 redraw，并支持实时 tick 增量更新。
- 扩展友好：可注册指标 renderer，支持自定义样式、主题和指标 key。
- 协议驱动：通过 `KLineItemProvider` 接入历史分页、区间补数和实时流。
- Swift 6 友好：数据提供者和 K 线数据模型要求 `Sendable`，加载流程使用 actor 隔离。

## 已实现功能

- [x] K 线蜡烛图绘制（阳线 / 阴线）
- [x] 手势交互（缩放、平移、十字线）
- [x] 实时数据订阅
- [x] 主指标：MA、EMA、WMA、BOLL、SAR
- [x] 副指标：MACD、RSI、VOL
- [x] 分时图模式
- [x] 自定义渲染器
- [x] 主题配置
- [x] 指标选择持久化
- [ ] 更多高级指标（持续迭代中）

# 快速开始

## 安装

目前推荐直接将 `Sources/SwiftKLine` 目录添加到工程，或在 Swift Package Manager 中引用本仓库。

## 基本使用

```swift
import UIKit
import SwiftKLine

let configuration = KLineConfiguration.themed(.midnight)
let klineView = KLineView(configuration: configuration)
view.addSubview(klineView)

// 选择周期并初始化数据提供者（示例用 Binance）
// 如需要切换周期，可重新构建 Provider
let provider = BinanceDataProvider(symbol: "BTCUSDT", period: .m1)
klineView.loadData(using: provider)
```

- `KLineItemProvider` 负责提供分页历史数据、按时间区间补数以及实时流。
- 框架内置 `KLineItemLoader`，会在前后台切换时自动补齐缺失区间。
- `loadData(using:)` 会重置当前数据、指标序列和分页状态，并启动新的 loader。

## 切换主图样式

```swift
klineView.setChartContentStyle(.candlestick)
klineView.setChartContentStyle(.timeSeries)
```

`KLineChartContentStyle` 当前支持：

- `.candlestick`：蜡烛图主图。
- `.timeSeries`：分时图主图。

## 创建自定义数据源

实现 `KLineItemProvider` 即可接入任意行情源：

```swift
final class MyProvider: KLineItemProvider, @unchecked Sendable {
    func fetchKLineItems(forPage page: Int) async throws -> [any KLineItem] { /* ... */ }
    func fetchKLineItems(from start: Date, to end: Date) async throws -> [any KLineItem] { /* ... */ }
    func liveStream() -> AsyncStream<any KLineItem> { /* 可选 */ }
}
```

说明：

- `page == 0` 表示最近一页，page 递增表示继续向更早历史分页。
- `fetchKLineItems(from:to:)` 用于前后台切换、网络恢复等场景的缺口补齐。
- `liveStream()` 默认返回空流；只有需要实时行情时才需要实现。
- Provider 必须是 `AnyObject & Sendable`。如果内部使用锁、actor 或不可变状态保证线程安全，可按需使用 `@unchecked Sendable`。

K 线数据模型需实现 `KLineItem`：

```swift
struct Candle: KLineItem {
    let opening: Double
    let closing: Double
    let highest: Double
    let lowest: Double
    let volume: Double
    let value: Double
    let timestamp: Int // 秒级时间戳
}
```

## 指标选择持久化

`KLineView` 默认使用 `UserDefaultsIndicatorSelectionStore` 保存主/副图指标选择。可以注入自定义 store，或传入 `nil` 关闭持久化：

```swift
let view = KLineView(indicatorSelectionStore: nil)
```

监听指标变化：

```swift
klineView.indicatorSelectionDidChange = { state in
    print(state.mainIndicators, state.subIndicators)
}
```

恢复默认指标：

```swift
klineView.resetIndicatorsToDefault()
```

# 配置与主题

## 使用内置主题

```swift
let dark = KLineConfiguration.themed(.midnight)
let light = KLineConfiguration.themed(.solaris)
let klineView = KLineView(configuration: dark)
```

## 自定义配置

```swift
let configuration = KLineConfiguration(
    candleStyle: CandleStyle(
        risingColor: .systemGreen,
        fallingColor: .systemRed,
        width: 8,
        gap: 2
    ),
    watermarkText: "SwiftKLine",
    layoutMetrics: LayoutMetrics(
        mainChartHeight: 320,
        timelineHeight: 16,
        indicatorHeight: 72,
        indicatorSelectorHeight: 34
    ),
    defaultMainIndicators: [.ma],
    defaultSubIndicators: [.vol, .macd]
)
```

自定义指标 key 和样式：

```swift
configuration.setIndicatorKeys([.ma(7), .ma(30)], for: .ma)
configuration.setIndicatorStyle(LineStyle(strokeColor: .systemPurple), for: .ma(7))
```

# 扩展框架

## 扩展内置指标渲染

框架当前提供的是“按指标注册渲染器 provider”的扩展点。  
你可以覆盖内置指标对应的渲染器实现，或追加同指标的额外渲染器。

```swift
import UIKit
import SwiftKLine

final class MyMARenderer: Renderer {
    var id: some Hashable { "my-ma-renderer" }
    var zIndex: Int { 10 } // 值越大越靠上绘制
    func install(to layer: CALayer) {}
    func uninstall(from layer: CALayer) {}
    func draw(in layer: CALayer, context: Context) {}
}

// 例如：为 MA 指标注册自定义渲染器 provider
KLineView.registerRenderer(for: .ma) { indicator, configuration in
    MyMARenderer()
}
```

说明：

- `registerRenderer` 是全局注册（静态），建议在 App 启动阶段完成。
- provider 会收到当前 `indicator` 与 `configuration`，可据此生成 renderer。
- 尚未提供按 `pass/zIndex` 管理任意 overlay renderer 的公开 API。

# 许可证

本项目采用 MIT 许可证 - 详情请见 LICENSE 文件。
