# 文档

[English](../README.md) | **简体中文**

从[项目 README](../../README.zh-CN.md) 开始安装并显示图表。以下指南对应当前源码中的 API。

## 指南

| 指南 | 阅读后可以了解 |
|---|---|
| [配置与集成](configuration.md) | 嵌入图表、更新配置、选择指标和处理错误 |
| [数据源与分页](data-providers.md) | 提供 K 线数据与独立分页的业务数据 |
| [插件与自定义图表](plugins.md) | 使用独立于其他图表的状态添加计算、叠加层和副图 |
| [架构与所有权](architecture.md) | 理解模块边界、数据发布、并发与渲染 |
| [性能与测量](performance.md) | 理解运行成本并测量计算与交互表现 |

## 推荐阅读路径

- **接入图表：**[快速开始](../../README.zh-CN.md#快速开始) → [配置与集成](configuration.md) → [数据源](data-providers.md)。
- **扩展图表：**[插件](plugins.md) → [独立范围分页](data-providers.md#独立范围分页) → [成交标记示例](../../SwiftKLineExample/TradeMarkers/TradeMarkerExample.swift)。
- **参与库开发：**[贡献指南](../../CONTRIBUTING.zh-CN.md) → [架构](architecture.md) → [性能](performance.md)。
- **查看变更：**[变更记录](../../CHANGELOG.zh-CN.md)。

## 产品与构建目标

| 名称 | 类型 | 职责 |
|---|---|---|
| `SwiftKLine` | 库产品与统一入口 target | 在 iOS 上导出 Core、UIKit 与 SwiftUI API |
| `SwiftKLineCore` | 库产品与 target | Foundation 模型、合并、计算器、类型化输出与范围分页 |
| `SwiftKLineUI` | 包内部 target | 配置、生命周期协调、UIKit 与 Core Animation 渲染 |
| `SwiftKLineSwiftUI` | 包内部 target | `UIViewRepresentable` 适配器 |

使用方可以添加的产品是 `SwiftKLine` 和 `SwiftKLineCore`。UI target 中的公开 API 由 `SwiftKLine` 重新导出，不作为独立包产品发布。

## 语言与示例约定

每页顶部提供 **English / 简体中文** 切换入口，直接打开相同主题的另一种语言版本。指南内的导航保持在当前语言。

英文指南位于 `docs/`，中文指南位于 `docs/zh-CN/`。根目录中文文档使用 `.zh-CN.md` 后缀。行为变更时同步更新两种语言。API 名称与可执行示例在两种语言中保持一致；源码注释使用英文。

提交文档变更前，在仓库根目录运行 `./script/validate-docs.py`。它会检查本地路径、标题链接、双语对应页面和可执行片段一致性。Swift 片段可在引用当前库的 iOS 应用 target 中编译验证；其他构建与测试命令见[贡献指南](../../CONTRIBUTING.zh-CN.md#构建与测试)。
