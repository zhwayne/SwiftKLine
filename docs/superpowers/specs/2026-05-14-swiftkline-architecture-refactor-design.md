# SwiftKLine 架构重构设计

日期：2026-05-14

## 背景

SwiftKLine 当前已经具备较好的内部模块雏形：数据加载由 `DataLoader` 承担，指标计算集中在 `IndicatorCalculationEngine` 和 `IndicatorCatalog`，渲染描述符由 `KLineDescriptorFactory` 生成，`KLineRendererReconciler` 负责 renderer 复用。但公共 API 和扩展边界仍然偏窄。

当前主要问题：

- `KLineView` 仍是事实上的总控入口，集中持有数据、loader、merger、指标选择、指标计算、renderer registry、手势状态、生命周期事件和 redraw 调度。
- `Indicator` 与 `Indicator.Key` 是封闭 enum，外部无法不改框架源码新增真正的自定义指标。
- `IndicatorCalculator`、`IndicatorSpec`、`IndicatorSeriesStore` 都不是公开扩展契约，导致计算和渲染扩展只能围绕内置指标打补丁。
- `IndicatorRendererRegistry.shared` 是全局静态注册表，两个 chart 实例无法天然拥有独立 renderer/plugin 配置。
- 当前测试主要覆盖数据合并和部分指标计算，缺少 API 兼容性、实例隔离、自定义插件、数据 pipeline、渲染 descriptor 的契约测试。

## 目标

本次重构的成功标准是：

1. API 易用性：业务接入者可以通过一站式配置完成数据源、主题、主图样式、默认指标、功能开关和错误回调组合。
2. 高扩展：外部使用者可以不修改 `Sources/SwiftKLine` 内置 enum，新增自定义指标、计算器、renderer 或 overlay。
3. 易维护：数据加载、指标计算、渲染描述符、交互状态、持久化和错误流拆成清晰内部模块。
4. 灵活特性：同一进程内的多个 `KLineView` 可以拥有不同 provider、指标集合、renderer/plugin registry 和功能开关，互不污染。
5. 兼容性：现有 `KLineView(configuration:)`、`loadData(using:)`、`setChartContentStyle(_:)`、`Indicator`、`Indicator.Key` 继续可用，并通过兼容层映射到新架构。

## 非目标

- 不在第一阶段重写所有 renderer 绘制细节。
- 不移除现有 `Indicator` API。
- 不把所有行为都塞进 initializer；周期切换、provider 更新、指标选择仍保留命令式入口。
- 不引入新的第三方依赖。

## 公共 API 设计

新增 `ChartConfiguration` 作为业务接入的一站式入口，`KLineConfiguration` 收窄为外观和样式层。

示例 API：

```swift
let view = KLineView(
    chart: ChartConfiguration(
        data: .provider(provider),
        appearance: .theme(.midnight),
        content: .candlestick,
        indicators: .init(
            main: [.builtIn(.ma), .builtIn(.boll)],
            sub: [.builtIn(.vol), .builtIn(.macd)]
        ),
        features: [.liveUpdates, .gapRecovery, .indicatorPersistence]
    )
)
```

设计原则：

- `KLineView` 继续作为公开 UIKit 入口，降低迁移成本。
- 新 initializer 面向新接入者，旧 initializer 作为兼容层保留。
- `ChartConfiguration` 负责组合数据、外观、内容模式、指标、插件和功能开关。
- `KLineConfiguration` 继续承载 `CandleStyle`、`LayoutMetrics`、字体、watermark、indicator style 等视觉配置。
- 旧的 `loadData(using:)` 和 `setChartContentStyle(_:)` 内部转发为 controller command。

建议类型：

```swift
public struct ChartConfiguration {
    public var data: DataSourceConfiguration
    public var appearance: KLineAppearanceConfiguration
    public var content: KLineChartContentStyle
    public var indicators: IndicatorSelectionConfiguration
    public var features: ChartFeatures
    public var plugins: PluginRegistry
}

public enum DataSourceConfiguration {
    case provider(any KLineItemProvider)
    case deferred
}

public enum KLineAppearanceConfiguration {
    case configuration(KLineConfiguration)
    case theme(KLineConfiguration.ThemePreset)
}
```

`KLineAppearanceConfiguration.theme(_:)` 只是便捷入口，内部仍生成 `KLineConfiguration`。这样新 API 可以表达“使用主题”，而已有样式系统不需要另起一套平行模型。

## 内部模块拆分

将当前 `KLineView` 的业务状态拆成五个内部模块：

### `KLineChartController`

统一接收外部命令：

- 加载或替换 provider
- 切换主图模式
- 选择、取消、重置指标
- 处理生命周期事件
- 转发 loading/error/selection 事件

`KLineView` 只调用 controller，不直接操作 loader、merger 或 calculator。

### `KLineDataPipeline`

承接当前数据相关职责：

- `DataLoader`
- `KLineDataMerger`
- 分页加载
- 前后台缺口补齐
- 网络恢复补数
- live tick 合并
- 加载错误事件

输出稳定的数据快照和错误事件。

### `KLineIndicatorPipeline`

承接指标相关职责：

- 指标选择和 normalize
- 指标选择持久化
- calculator 构造
- 指标序列计算
- 内置指标和自定义插件的统一调度

### `KLineRenderPipeline`

承接渲染描述符和 renderer 管理：

- 根据 chart state 生成 `ChartDescriptor`
- 生成 main/sub/overlay/crosshair renderer group
- 管理 renderer reconcile
- 按实例读取 plugin registry

### `KLineChartState`

作为单一状态快照：

- `items`
- `indicatorSeriesStore`
- `contentStyle`
- `selectedIndex`
- `selectedLocation`
- `loadingState`
- `lastError`
- 当前指标选择

状态流：

```text
外部 API
  -> KLineChartController command
  -> KLineDataPipeline / KLineIndicatorPipeline
  -> KLineChartState 更新
  -> KLineRenderPipeline 生成 descriptor
  -> KLineView drawVisibleContent
```

## 指标与渲染插件体系

当前扩展性瓶颈来自 `Indicator` / `Indicator.Key` 的封闭 enum。新设计引入开放 ID 和序列 key。

```swift
public struct IndicatorID: Hashable, Sendable, Codable, ExpressibleByStringLiteral {
    public let rawValue: String
}

public struct SeriesKey: Hashable, Sendable, CustomStringConvertible {
    public let indicatorID: IndicatorID
    public let name: String
    public let parameters: [String: String]
}

public enum IndicatorPlacement: Sendable {
    case main
    case sub
    case overlay
}
```

新增插件协议：

```swift
public protocol KLineIndicatorPlugin: Sendable {
    var id: IndicatorID { get }
    var title: String { get }
    var placement: IndicatorPlacement { get }
    var defaultSeriesKeys: [SeriesKey] { get }

    func makeCalculators(configuration: KLineConfiguration) -> [any KLineIndicatorCalculator]
    @MainActor func makeRenderers(configuration: KLineConfiguration) -> [any Renderer]
}
```

公开计算协议：

```swift
public protocol KLineIndicatorCalculator: Sendable {
    associatedtype Value: Sendable

    var id: SeriesKey { get }
    func calculate(for items: [any KLineItem]) -> [Value?]
}
```

`IndicatorSeriesStore` 改为开放 key 的类型擦除存储：

```swift
struct IndicatorSeriesStore {
    private var series: [SeriesKey: AnyIndicatorSeries]
}
```

`AnyIndicatorSeries` 是内部类型擦除容器，保存同一 `SeriesKey` 对应的 `ContiguousArray<Value?>`。外部不直接操作该容器，只通过 `RendererContext` 的类型化读取 API 访问。

渲染上下文提供类型安全读取 API：

```swift
extension RendererContext {
    public func values<Value>(
        for key: SeriesKey,
        as type: Value.Type
    ) -> ContiguousArray<Value?>?
}
```

内置指标迁移：

- `Indicator.ma` 映射到 `IndicatorID("builtin.ma")`
- `.ma(5)` 映射到 `SeriesKey(indicatorID: "builtin.ma", name: "MA", parameters: ["period": "5"])`
- MA/EMA/WMA/BOLL/SAR/VOL/RSI/MACD 都改为内置 plugin
- 旧 renderer 先保留，内部读取新 series key

## 实例级 Registry

替代当前 `IndicatorRendererRegistry.shared` 的新入口：

```swift
public final class PluginRegistry {
    public func register(_ plugin: any KLineIndicatorPlugin)
    public func registerRenderer(
        placement: RendererPlacement,
        provider: @escaping KLineRendererProvider
    )
}
```

建议补齐的 renderer 注册模型：

```swift
public enum RendererPlacement: Sendable {
    case main
    case sub(IndicatorID)
    case overlay
    case crosshair
}

public typealias KLineRendererProvider = @MainActor (
    RendererPlacement,
    KLineConfiguration
) -> [any Renderer]
```

设计要求：

- 每个 `ChartConfiguration` 持有自己的 registry。
- 默认 registry 注册所有内置指标和默认 renderer。
- `KLineView.registerRenderer(for:)` 作为旧全局兼容 API 保留，但新代码推荐使用实例 registry。
- 两个 `KLineView` 使用不同 registry 时，renderer 和插件互不影响。

## 兼容策略

保留旧 API：

- `KLineView(configuration:indicatorSelectionStore:)`
- `loadData(using:)`
- `setChartContentStyle(_:)`
- `resetIndicatorsToDefault()`
- `indicatorSelectionDidChange`
- `onLoadError`
- `KLineView.registerRenderer(for:)`
- `Indicator`
- `Indicator.Key`
- `KLineConfiguration.setIndicatorKeys`
- `KLineConfiguration.setIndicatorStyle`

兼容层行为：

- 旧 initializer 构造默认 `ChartConfiguration`。
- `loadData(using:)` 转为 controller 的 provider replacement command。
- `setChartContentStyle(_:)` 转为 controller 的 content style command。
- `Indicator` / `Indicator.Key` 映射为新 `IndicatorID` / `SeriesKey`。
- 旧全局 renderer registry 在创建默认 registry 时合并，避免已有启动期注册丢失。

## 实施拆分

1. 抽出 `KLineChartState` 和 `KLineChartController`，保持旧 API 行为不变。
   verify: `KLineView` 不再直接持有核心业务对象；旧示例仍可编译。

2. 把 loader、merger、网络恢复迁入 `KLineDataPipeline`。
   verify: 分页、live tick、补数、错误事件有独立单测。

3. 把指标选择、持久化、calculator 调度迁入 `KLineIndicatorPipeline`。
   verify: 指标选择 normalize、持久化、计算结果归并有独立单测。

4. 引入 `IndicatorID` / `SeriesKey` 和旧 `Indicator` 映射层。
   verify: 内置指标计算结果可以通过新 key 读取；旧 key API 仍可用。

5. 引入 `KLineIndicatorPlugin`、`KLineIndicatorCalculator` 和实例级 `PluginRegistry`。
   verify: 内置指标走插件路径注册。

6. 改造 `IndicatorSeriesStore` 和 `RendererContext`。
   verify: 外部 renderer 可以通过开放 key 读取自定义 series。

7. 改造 `KLineRenderPipeline` 和 descriptor factory。
   verify: main/sub/overlay placement 生成正确 renderer group；renderer reconcile 不重复 install/uninstall。

8. 更新 README、示例 App 和测试。
   verify: README 覆盖快速接入、自定义数据源、自定义指标、自定义 renderer、旧 API 迁移。

## 测试矩阵

### API 易用性

- 新增测试或示例验证 `ChartConfiguration` 可以一次性配置 provider、主题、默认指标、主图样式和功能开关。

### 兼容性

- 现有 `KLineView(configuration:) + loadData(using:)` 编译通过。
- `setChartContentStyle(_:)` 行为不变。
- 旧 `Indicator` 和 `Indicator.Key` 配置仍可生成对应指标。

### 实例隔离

- 创建两个 `KLineView`，分别注入不同 registry。
- 一个 view 注册自定义 renderer，另一个 view 不出现该 renderer。

### 自定义指标

- 测试 target 定义自定义 `KLineIndicatorPlugin`。
- 插件不修改内置 `Indicator` enum。
- 插件 calculator 能写入 series。
- 插件 renderer 能从 `RendererContext` 读取 series。

### 数据流

- `KLineDataPipeline` 覆盖分页加载、空页结束、live tick 替换、live tick 插入、前后台补数和错误事件。

### 指标流

- `KLineIndicatorPipeline` 覆盖选择 normalize、默认值、持久化、计算取消和并发计算归并。

### 渲染流

- `KLineRenderPipeline` 覆盖 main/sub/overlay group 生成。
- renderer reconcile 覆盖新增、删除、排序稳定性。

## 验证命令

Swift Package 当前直接执行 `swift test` 会在 macOS 目标上失败，因为源码使用 UIKit。实施阶段应使用 iOS 目标验证，例如：

```bash
xcodebuild -project SwiftKLineExample.xcodeproj -scheme SwiftKLineExample -destination 'generic/platform=iOS Simulator' build
```

如后续配置了真实设备并满足签名条件，按仓库规则优先使用真机构建/测试。

## 完成判定

只有同时满足以下条件，才认为本次架构重构完成：

- 新公共 API 已实现并在示例中使用。
- 旧公共 API 仍可编译并通过兼容测试。
- 外部自定义指标插件可以在测试 target 中定义、计算、渲染。
- 多实例 registry 隔离通过测试。
- `KLineView` 不再承担数据加载、指标计算和 registry 管理的核心职责。
- README 覆盖新 API、旧 API 迁移和插件扩展。
- iOS 构建/测试通过，或记录明确的环境阻塞和替代验证证据。
