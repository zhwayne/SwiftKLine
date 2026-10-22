# 变更记录

[English](CHANGELOG.md) | **简体中文**

以下按阶段记录重要变更。`Unreleased` 描述当前开发工作区，不代表已发布版本。日期章节来自 Git 历史中的开发里程碑，不是版本标签。当前仓库没有发布标签。

## Unreleased

### 新增

- 九项附图指标：KDJ、CCI、WR、DMI、ATR、OBV、ROC、MFI、TRIX，支持包含参数的序列标识、公开 KDJ/DMI 配色、国际默认参数、参考线，以及独立选择与持久化。

- 内置 BBI、VWMA、Donchian 主图指标，提供可复用的通道渲染和包含参数的序列标识。
- 内置 SuperTrend（SUPER）、Ichimoku（ICHI）主图指标，提供趋势方向色带与翻转断线，以及五线云图叠加。
- UIKit 与 SwiftUI 共用的 `ChartConfiguration` API，包含 `CandleSource`、`ChartAppearance`、展示模式、插件、指标选择和能力开关。
- `ChartPlugin` 生命周期，提供每图表独立协调器、局部资源注册、序列隔离、错误报告和重绘请求。
- 通过 `RangeDataProvider`、`RangePage` 和 `RangeLoader` 实现独立时间范围分页，支持覆盖、重试、取消与有界缓存。
- 应用自有的成交标记示例，包含 provider、插件、渲染和回归覆盖。
- 完整英文和简体中文文档、对应页面语言切换、文档索引、贡献指南和变更记录。

### 变更

- 分时图的面积填充改为从上到下逐渐透明的渐变，并裁剪在价格折线下方。
- 分时模式保留最新价格标签、价格指示线和返回最新位置控件，仅隐藏 K 线高低点标注。
- 分时折线可见的最新点显示同色实心圆点，价格虚线的端点与圆心对齐。

- 内置指标接入插件流水线，保留选择器、持久化、外观和布局行为。
- K 线与对应指标输出按一致批次发布；独立外部数据不延迟主数据发布。
- 历史和配置失效请求抢占合并实时更新的定时器。
- 通过资源命名空间支持同一图表中的多个功能实例。
- 文档接入流程现在链接完整网络数据源，用决策表解释选择状态优先级，并在 CI 中校验双语链接与代码片段。

### 修复

- 修正文档中的合并覆盖顺序、恢复与重试边界、选择状态持久化、插件 ID、范围加载通知和基准测试范围说明。
- 视口与场景输入不再每次都使图例缓存失效。
- 分时缓存能够检测中间 K 线的修订。
- 取消的计算任务不再消耗下一次刷新的调度状态。

## 2026-10-21

### 变更

- 拆分 Core、UIKit、SwiftUI 与统一入口 target，优化指标计算和绘制，移除第三方布局依赖（[c017603](https://github.com/zhwayne/SwiftKLine/commit/c017603)）。

### 修复

- 防止过期图表更新，清理实时订阅（[982f2b2](https://github.com/zhwayne/SwiftKLine/commit/982f2b2)）。

## 2026-05-17

### 变更

- 收敛公开 API、重命名指标类型并删除旧代码（[e94f5be](https://github.com/zhwayne/SwiftKLine/commit/e94f5be)、[fcbc1cb](https://github.com/zhwayne/SwiftKLine/commit/fcbc1cb)）。
- 将 KLine 概念重命名为 Chart，并重新设计配置（[b9ea9d6](https://github.com/zhwayne/SwiftKLine/commit/b9ea9d6)）。
- 移除过时的仓库文件（[75b9ec7](https://github.com/zhwayne/SwiftKLine/commit/75b9ec7)）。

## 2026-05-13

### 新增

- MACD 和 BOLL 参数可配置（[56fe301](https://github.com/zhwayne/SwiftKLine/commit/56fe301)）。

### 修复

- 加载器错误处理与不安全的强制解包（[72d539e](https://github.com/zhwayne/SwiftKLine/commit/72d539e)）。

## 2026-04-27

### 变更

- 提取数据加载 actor（[c873a87](https://github.com/zhwayne/SwiftKLine/commit/c873a87)）、计算引擎（[bbe5137](https://github.com/zhwayne/SwiftKLine/commit/bbe5137)）与渲染协调器（[19b756e](https://github.com/zhwayne/SwiftKLine/commit/19b756e)）。
- 更新使用文档（[5b1d68b](https://github.com/zhwayne/SwiftKLine/commit/5b1d68b)）。

## 2026-02

### 变更

- 重构指标流水线并集中指标规格（[0afc4fa](https://github.com/zhwayne/SwiftKLine/commit/0afc4fa)）。

### 修复

- 分页耗尽与历史页重复（[a039157](https://github.com/zhwayne/SwiftKLine/commit/a039157)）。

## 2025-12

### 变更

- 降低重绘成本（[e526a27](https://github.com/zhwayne/SwiftKLine/commit/e526a27)），简化渲染计算与十字光标行为（[e5df64e](https://github.com/zhwayne/SwiftKLine/commit/e5df64e)）。

### 修复

- 涨跌幅与振幅计算的除零问题（[5bbad40](https://github.com/zhwayne/SwiftKLine/commit/5bbad40)）。

## 2025-11

### 新增

- WMA 计算与渲染（[1a2c947](https://github.com/zhwayne/SwiftKLine/commit/1a2c947)）。
- 时间桶时长管理（[334e411](https://github.com/zhwayne/SwiftKLine/commit/334e411)）。
- 指标选择持久化（[85ce67e](https://github.com/zhwayne/SwiftKLine/commit/85ce67e)）与自定义渲染器管理（[2f19fb5](https://github.com/zhwayne/SwiftKLine/commit/2f19fb5)）。

### 修复

- 价格标签跟随当前布局边界（[d043492](https://github.com/zhwayne/SwiftKLine/commit/d043492)）。

## 2025-04

### 新增

- MACD 渲染（[ec4eff8](https://github.com/zhwayne/SwiftKLine/commit/ec4eff8)）、Binance provider 示例（[69cdba7](https://github.com/zhwayne/SwiftKLine/commit/69cdba7)）与周期切换（[d914653](https://github.com/zhwayne/SwiftKLine/commit/d914653)）。

### 变更

- 引入当时的 `KLineItemProvider` API（[6470b7e](https://github.com/zhwayne/SwiftKLine/commit/6470b7e)），调整源码布局（[a8832d7](https://github.com/zhwayne/SwiftKLine/commit/a8832d7)）。现行 API 名称请以[当前指南](docs/zh-CN/README.md) 为准。
