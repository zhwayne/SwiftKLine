# 变更记录

[English](CHANGELOG.md) | **简体中文**

以下按阶段记录重要变更。`Unreleased` 描述当前开发工作区，不代表已发布版本。日期章节来自 Git 历史中的开发里程碑，不是版本标签。当前仓库没有发布标签。

## Unreleased

### 新增

- 文档按接入主线重组：新增快速开始、内置指标与外观定制指南；配置与数据源指南重新组织；文档索引更新并给出阅读路径。

- 九项附图指标：KDJ、CCI、WR、DMI、ATR、OBV、ROC、MFI、TRIX，支持包含参数的序列标识、公开 KDJ/DMI 配色、国际默认参数、参考线，以及可编码的选择状态。

- 内置 BBI、VWMA、Donchian 主图指标，提供可复用的通道渲染和包含参数的序列标识。
- 内置 SuperTrend（SUPER）、Ichimoku（ICHI）主图指标，提供趋势方向色带与翻转断线，以及五线云图叠加。
- UIKit 与 SwiftUI 共用的 `ChartConfiguration` API，包含 `CandleSource`、`ChartAppearance`、展示模式、插件和能力开关；周期与指标选择由应用管理。
- `ChartPlugin` 生命周期，提供每图表独立协调器、局部资源注册、序列隔离、错误报告和重绘请求。
- 通过 `RangeDataProvider`、`RangePage` 和 `RangeLoader` 实现独立时间范围分页，支持覆盖、重试、取消与有界缓存。
- 应用自有的成交标记示例，包含 provider、插件、渲染和回归覆盖。
- 完整英文和简体中文文档、对应页面语言切换、文档索引、贡献指南和变更记录。

### 变更

- 主 K 线加载会话下沉至 `SwiftKLineCore`（package 访问级别），历史分页、实时消费与缺口恢复可在无 UIKit 环境下运行和测试；UIKit target 仅消费其事件。
- 配置失效判定收敛为同一套比较逻辑，由视图与协调器共同使用，统一数据源重启、几何重建与重绘的判断。
- 将偏好、存储与迁移实现移入示例应用。新增稳定的 ChartScreenState，统一一次恢复、变化保存和离线预览。ChartAppearance 仅持有视觉设置，计算 key 由 IndicatorConfiguration 独立管理，可选指标与默认选择归应用。
- shutdown 成为幂等终止操作，清理观察者和绘制任务并拒绝后续更新。未变的内置声明与可比较样式跳过协调和重绘，自定义插件保留更新与主动重绘契约。
- SwiftUI 桥接移至示例应用，移除 `SwiftKLineSwiftUI` target 和库导出。应用自有的 `KLineChart` 及其测试与 UIKit 库分离；公开 `ChartView.shutdown()` 供应用结束会话。
- 分时图的面积填充改为从上到下逐渐透明的渐变，并裁剪在价格折线下方。
- 分时模式保留最新价格标签、价格指示线和返回最新位置控件，仅隐藏 K 线高低点标注。
- 分时折线可见的最新点显示同色实心圆点，价格虚线的端点与圆心对齐。

- 内置指标接入插件流水线，保留选择、外观和布局行为。
- 用独立配置与 `IndicatorSelection` 输入替换 `ChartSelection` 及其控制器。UIKit 提供 `indicators`、`resolvedIndicators`、`setIndicators(_:)` 和 `apply(_:indicators:)`；SwiftUI 消费值，不再有绑定回写协调。
- 应用管理周期校验、数据源构造和偏好生命周期。可选的 `ChartPreferences` 在首次 provider 会话前恢复旧记录，保存由应用显式触发。指标请求在临时可用性变化期间保留。
- 示例应用提供自有的 `ChartStateStore`、UserDefaults/内存实现及类型安全的 `.chartPreferences` key。图表不再接收 store，namespace 隔离应用偏好。
- K 线与对应指标输出按一致批次发布；独立外部数据不延迟主数据发布。
- 历史和配置失效请求抢占合并实时更新的定时器。
- 通过资源命名空间支持同一图表中的多个功能实例。
- 文档接入流程现在链接完整网络数据源，用决策表解释选择状态优先级，并在 CI 中校验双语链接与代码片段。

### 修复

- 修复非活跃新数据源仍订阅实时流、乱序活跃状态与恢复重新激活的问题；历史加载仍可继续。
- 收紧样式跳过逻辑，避免共享可变 Equatable 样式漏掉重绘；插件在调用清理回调前移除所有权，避免重入时重复拆卸。
- 图例按可用尺寸重新测量；修正捏合累积误差、逻辑锚点及取消/解绑清理，十字光标保留小价格；增加有限几何和安全索引转换约束。
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
