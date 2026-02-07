![SwiftKLine](https://socialify.git.ci/zhwayne/SwiftKLine/image?description=1&font=KoHo&forks=1&issues=1&language=1&name=1&owner=1&pattern=Circuit+Board&pulls=1&stargazers=1&theme=Auto)

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
- [x] 实时数据订阅
- [x] 主指标：MA、EMA、WMA、BOLL、SAR
- [x] 副指标：MACD、RSI、VOL
- [x] 分时图模式
- [x] 自定义渲染器
- [X] 主题配置
- [ ] 更多高级指标（持续迭代中）

# 快速开始

## 安装

目前推荐直接将 `Sources/SwiftKLine` 目录添加到工程，或在 Swift Package Manager 中引用本仓库。

## 基本使用

```swift
import UIKit
import SwiftKLine

let klineView = KLineView()
view.addSubview(klineView)

// 选择周期并初始化数据提供者（示例用 Binance）
// 如需要切换周期，可重新构建 Provider
let provider = BinanceDataProvider(symbol: "BTCUSDT", period: .m1)
klineView.setProvider(provider)
```

- `KLineItemProvider` 负责提供分页历史数据、按时间区间补数以及实时流。
- 框架内置 `KLineItemLoader`，会在前后台切换时自动补齐缺失区间。

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
