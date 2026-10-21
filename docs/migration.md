# 接入与迁移

## 保留的入口

`import SwiftKLine`、`ChartView`、`ChartOptions`、主题、`loadData(using:)`、`setContentStyle`、指标选择持久化及原有插件协议继续可用。公开数据类型现在由 Core 定义，通过统一入口重新导出。

内置计算器和输出类型新增为公共 API，业务不再需要 `@testable import` 才能计算指标。仅计算场景可改为依赖 SPM 的 `SwiftKLineCore` 产品。

源代码已按模块移动；通过 SPM 接入即可。手动复制代码时必须包含相关模块并正确设置依赖，旧的“仅复制 Sources/SwiftKLine”方式不再适用。该改动不承诺预编译二进制的 ABI 兼容。

## 明确周期

旧代码从相邻历史间隔猜测桶周期，存在把历史缺口当作大周期的风险。现在默认按精确时间戳识别；如果实时消息使用桶内更新时间，请提供固定周期：

```swift
var candlePeriod: ChartPeriod? { .oneMinute }
```

或者手动模式使用 `chart.setItems(items, period: .oneMinute)`。月线等日历周期使用开盘时间戳并保持 nil；`ChartPeriod.oneMonth.seconds` 只是近似值。

## SwiftUI

应用自己的 UIViewRepresentable 可替换为库提供的 `KLineChart`。把 symbol / period 等数据源身份放到 `sourceID`，通过 provider 工厂延迟创建连接，避免在每次 `body` 计算时实例化和重载 provider。

`content:` 与 `indicators:` Binding 支持动态更新。主题、布局和插件是创建时配置，改变这些配置时用 `.id(...)` 重建。

## 自定义计算器与渲染器

`IndicatorCalculator` 新增 `update(for:values:from:)`，但有默认实现，现有实现只需要保留 `calculate`。跨任务传递的输出类型必须遵守 Sendable；可以优先使用 struct，避免通过 unchecked Sendable 绕过编译器。

标量折线可直接使用 `LineIndicatorRenderer(series:)`。渲染器身份必须包含所有影响行为的参数；多个 BOLL / MACD / SAR 参数实例现在分别按 SeriesKey 复用。

指标序列读取类型必须一致。例如 Double 输出使用 `as: Double.self`；Int 和 Double 不会自动互转。`IndicatorEngine` 会把插件错误长度的输出补齐 nil 或截断，避免索引错位。

原内部 MA / EMA / WMA renderer 已合并，不属于公开 API。使用这些内部类型的测试需要改用 `LineIndicatorRenderer`。

## 数据与异步行为

`setItems` 提供独立于 provider 的数据接入，并停止原 provider。`update` 接收单根完整快照。实时绘制合并为批次，默认等待 200 ms；期间全部 tick 仍合入原始数据，界面与指标按同一快照提交。

若直接使用内部 loader 进行测试，`stop` 现在是终态。恢复或替换数据源时创建新 loader，公共 `loadData` 已完成这一步。

SnapKit 和示例中的 SwiftyJSON 已移除，包不再需要下载任何第三方库。
