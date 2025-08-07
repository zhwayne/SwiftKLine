一个轻量级、模块化且易于扩展的K线图表框架，专为Swift应用设计。

<img src="https://github.com/user-attachments/assets/efa0309e-72c6-4d2a-8d27-60891d7bfcda" width=50%>


# 功能特点

## 核心架构

🧱 模块化设计 - 各组件独立解耦，可自由组合替换
⚡️ 高性能渲染 - 优化绘图逻辑，支持流畅的实时数据更新
🧩 扩展友好 - 易于添加新指标和自定义视图
🎛️ 高度可配置 - 通过协议驱动定制UI和行为

## 已实现功能

- [x] K线蜡烛图绘制（阳线/阴线）
- [ ] 分时图模式
- [x] 手势交互（缩放、平移）
- [x] MA（移动平均线）
- [x] EMA（指数移动平均线）
- [x] BOLL（布林带）
- [x] SAR（抛物线转向指标）
- [x] MACD（异同移动平均线）
- [ ] KDJ（随机指标）
- [x] RSI（相对强弱指数）
- [x] VOL（成交量）

## 待完成功能

⏳ 更多高级指标（开发中）
⏳ WebSocket 实时更新

# 快速开始

## 基本使用

```swift
import SwiftKLine

let klineView = KLineView()
view.addSubview(klineView)

// 配置数据源
let provider = BinanceDataProvider(period: period)
klineView.setProvider(provider)

// 添加 websocket 支持
// TODO: 暂未实现
```

# 扩展框架

## 添加自定义指标

待完成...

# 许可证

本项目采用 MIT 许可证 - 详情请见 LICENSE 文件
