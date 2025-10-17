一个轻量级、模块化且易于扩展的 K 线图表框架，专为 Swift 应用设计。

<img src="https://github.com/user-attachments/assets/efa0309e-72c6-4d2a-8d27-60891d7bfcda" width=50%>


# 功能特点

## 核心架构

🧱 模块化设计 - 各组件独立解耦，可自由组合替换
⚡️ 高性能渲染 - 优化绘图逻辑，支持流畅的实时数据更新
🧩 扩展友好 - 易于添加新指标和自定义视图
🎛️ 协议驱动 - 通过数据提供者协议自定义行为

## 已实现功能

- [x] K 线蜡烛图绘制（阳线 / 阴线）
- [x] 手势交互（缩放、平移、十字线）
- [x] 实时数据订阅（内置断线补数逻辑）
- [x] 主指标：MA、EMA、BOLL、SAR
- [x] 副指标：MACD、RSI、VOL
- [x] 分时图模式
- [ ] 更多高级指标（持续迭代中）

# 快速开始

## 安装

目前推荐直接将 `Sources/SwiftKLine` 目录添加到工程，或在 Swift Package Manager 中引用本仓库。

## 基本使用

```swift
import SwiftKLine

let klineView = KLineView()
view.addSubview(klineView)

// 选择周期并初始化数据提供者（示例用 Binance）
let provider = BinanceDataProvider(symbol: "BTCUSDT", period: .m1)
klineView.setProvider(provider)
```

- `KLineItemProvider` 负责提供分页历史数据、按时间区间补数以及实时流。
- 框架内置 `KLineItemLoader`，会在前后台切换时自动补齐缺失区间并恢复 WebSocket。

## 创建自定义数据源

实现 `KLineItemProvider` 即可接入任意行情源：

```swift
final class MyProvider: KLineItemProvider {
    func fetchKLineItems(forPage page: Int) async throws -> [any KLineItem] { /* ... */ }
    func fetchKLineItems(from start: Date, to end: Date) async throws -> [any KLineItem] { /* ... */ }
    func liveStream() -> AsyncStream<any KLineItem> { /* 可选 */ }
}
```

# 扩展框架

## 添加自定义指标

指标遵循 `Indicator` 协议，通过 `IndicatorTypeView` 管理器即可在运行时切换。示例和更多文档待补充。

# 许可证

本项目采用 MIT 许可证 - 详情请见 LICENSE 文件。
