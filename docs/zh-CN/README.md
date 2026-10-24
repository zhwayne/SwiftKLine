# 文档

[English](../README.md) | **简体中文**

从[项目 README](../../README.zh-CN.md)或[快速开始](getting-started.md)开始安装并显示图表。以下指南对应当前源码中的 API。

## 指南

| 指南 | 阅读后可以了解 |
|---|---|
| [快速开始](getting-started.md) | 添加依赖、构建配置，并在 SwiftUI 与 UIKit 中渲染图表 |
| [配置与集成](configuration.md) | 配置字段、更新语义、功能开关、错误上报与图表 API |
| [数据源接入](data-providers.md) | K 线净值契约、历史分页、实时快照、缺口恢复与独立业务数据 |
| [内置指标](indicators.md) | 指标目录、共享状态存储、选择、参数以及 Core 计算器 |
| [外观定制](appearance.md) | 主题、蜡烛样式、布局、图例水印与按 key 的指标样式 |
| [插件与自定义图表](plugins.md) | 自定义计算、叠加层与副图，以及每图表独立状态 |
| [架构与所有权](architecture.md) | 模块边界、数据发布、并发与渲染（深入） |
| [性能与测量](performance.md) | 运行成本、基准测试与测量方法（深入） |

## 推荐阅读路径

- **接入图表：**[快速开始](getting-started.md) → [配置与集成](configuration.md) → [数据源接入](data-providers.md)。
- **调整内置能力：**[内置指标](indicators.md) → [外观定制](appearance.md)。
- **扩展图表：**[插件](plugins.md) → [独立范围分页](data-providers.md#独立范围分页) → [成交标记示例](../../SwiftKLineExample/TradeMarkers/TradeMarkerExample.swift)。
- **参与库开发：**[贡献指南](../../CONTRIBUTING.zh-CN.md) → [架构](architecture.md) → [性能](performance.md)。
- **查看变更：**[变更记录](../../CHANGELOG.zh-CN.md)。

## 产品与构建目标

| 名称 | 类型 | 职责 |
|---|---|---|
| `SwiftKLine` | 库产品与统一入口 target | 在 iOS 上导出 Core 与 UIKit API |
| `SwiftKLineCore` | 库产品与 target | Foundation 模型、合并、计算器、类型化输出、范围分页与主 K 线加载会话 |
| `SwiftKLineUI` | 包内部 target | 配置、生命周期协调、UIKit 与 Core Animation 渲染 |

包使用者可用的两个库产品是 `SwiftKLine` 和 `SwiftKLineCore`。UIKit target 包含由 `SwiftKLine` 再导出的公开 API，它不是独立包产品。SwiftUI 桥接属于应用代码，示例提供了轻量的 `UIViewRepresentable` 包装。

## 双语与示例

每份文档页面顶部都有 **English / 简体中文** 切换，指向同页的另一语言。页面内的导航保持当前语言。

英文指南位于 `docs/`；中文指南位于 `docs/zh-CN/`。根级文档的中文版使用 `.zh-CN.md` 后缀。行为变化时请同时更新两个版本。API 名称与可执行示例在两种语言中保持一致；代码注释保持英文。

提交文档变更前，请在仓库根目录运行 `./script/validate-docs.py`。它检查本地路径、标题锚点、双语对应与可执行片段一致性。Swift 片段需在 iOS 应用 target 中用当前库编译。其它构建与测试命令见[贡献指南](../../CONTRIBUTING.zh-CN.md#构建与测试)。
