# SwiftKLine Architecture Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor SwiftKLine so its public API is easier to use, indicators/renderers are extensible without editing built-in enums, internal responsibilities are maintainable, and multiple chart instances can use isolated configuration.

**Architecture:** Keep `KLineView` as the public UIKit entry point while moving data, indicator, and render orchestration into focused internal modules. Add a new `ChartConfiguration` facade, open indicator/plugin identifiers, an instance-level plugin registry, and compatibility mappings for the existing `Indicator` API.

**Tech Stack:** Swift 6, UIKit, Swift Package Manager, Xcode iOS build, Swift Testing, SnapKit.

---

## Verification Notes

`swift test` currently fails on macOS because the package imports UIKit. During execution, use iOS-oriented verification:

```bash
xcodebuild -project SwiftKLineExample.xcodeproj -scheme SwiftKLineExample -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

If the sandbox blocks Xcode caches or CoreSimulator access, record the exact error and run the closest available compile command with an explicit writable derived data path:

```bash
xcodebuild -project SwiftKLineExample.xcodeproj -scheme SwiftKLineExample -destination 'generic/platform=iOS' -derivedDataPath /tmp/swiftkline-deriveddata build CODE_SIGNING_ALLOWED=NO
```

When a real device is configured and signing is available, prefer a device build/test per repository instructions.

## File Structure

Create these files:

- `Sources/SwiftKLine/API/ChartConfiguration.swift`: new facade configuration types, feature options, and appearance/data source wrappers.
- `Sources/SwiftKLine/API/KLineIndicatorIdentity.swift`: open indicator IDs, series keys, placement enums, and compatibility helpers.
- `Sources/SwiftKLine/API/PluginRegistry.swift`: instance-level plugin and renderer registry.
- `Sources/SwiftKLine/Indicator/KLineIndicatorPlugin.swift`: public plugin and calculator protocols plus type erasure.
- `Sources/SwiftKLine/Indicator/BuiltInIndicatorPlugins.swift`: built-in MA/EMA/WMA/BOLL/SAR/VOL/RSI/MACD plugins.
- `Sources/SwiftKLine/Data/KLineChartState.swift`: internal chart state snapshot.
- `Sources/SwiftKLine/Data/KLineDataPipeline.swift`: pagination, recovery, live tick, and data merge orchestration.
- `Sources/SwiftKLine/Data/KLineIndicatorPipeline.swift`: selection normalization, persistence, calculator construction, and series calculation.
- `Sources/SwiftKLine/Renderer/KLineRenderPipeline.swift`: descriptor creation with instance registry and renderer placement support.
- `Tests/SwiftKLineTests/ArchitectureRefactorTests.swift`: API, compatibility, custom plugin, and registry isolation tests.

Modify these files:

- `Sources/SwiftKLine/View/KLineView.swift`: delegate commands to controller/pipelines, add new initializer, preserve compatibility methods.
- `Sources/SwiftKLine/Renderer/KLineDescriptorFactory.swift`: stop reading global `IndicatorRendererRegistry.shared`; accept registry/pipeline inputs.
- `Sources/SwiftKLine/View/IndicatorRendererRegistry.swift`: turn into compatibility bridge for old global renderer registration.
- `Sources/SwiftKLine/Data/RendererContext.swift`: add open-key series access while keeping existing typed helpers.
- `Sources/SwiftKLine/Data/IndicatorSeriesStore.swift`: migrate storage to `SeriesKey` while preserving compatibility readers.
- `Sources/SwiftKLine/Calculator/IndicatorCalculator.swift`: bridge existing calculators to the public calculator protocol.
- `Sources/SwiftKLine/Indicator/Indicator.swift`: add compatibility mapping to `IndicatorID` and `SeriesKey`.
- `Sources/SwiftKLine/Indicator/IndicatorCatalog.swift`: migrate built-in specs toward plugin registration.
- `SwiftKLineExample/KLineSwiftUIView.swift`: demonstrate the new facade initializer.
- `README.md`: document new facade API, plugin API, registry isolation, and old API migration.

## Task 1: Add Open Indicator Identity Types

**Files:**
- Create: `Sources/SwiftKLine/API/KLineIndicatorIdentity.swift`
- Modify: `Sources/SwiftKLine/Indicator/Indicator.swift`
- Test: `Tests/SwiftKLineTests/ArchitectureRefactorTests.swift`

- [ ] **Step 1: Write failing identity mapping tests**

Add this to `Tests/SwiftKLineTests/ArchitectureRefactorTests.swift`:

```swift
import Testing
@testable import SwiftKLine

@Test func indicatorIDSupportsStringLiteralAndRawValue() {
    let id: IndicatorID = "custom.vwap"

    #expect(id.rawValue == "custom.vwap")
    #expect(String(describing: id) == "custom.vwap")
}

@Test func builtInIndicatorMapsToStableOpenID() {
    #expect(Indicator.ma.kLineID == IndicatorID("builtin.ma"))
    #expect(Indicator.macd.kLineID == IndicatorID("builtin.macd"))
}

@Test func builtInIndicatorKeysMapToStableSeriesKeys() {
    let ma = Indicator.Key.ma(5).kLineSeriesKey
    let macd = Indicator.Key.macd(shortPeriod: 12, longPeriod: 26, signalPeriod: 9).kLineSeriesKey

    #expect(ma.indicatorID == "builtin.ma")
    #expect(ma.name == "MA")
    #expect(ma.parameters == ["period": "5"])
    #expect(String(describing: ma) == "builtin.ma.MA(period=5)")

    #expect(macd.indicatorID == "builtin.macd")
    #expect(macd.name == "MACD")
    #expect(macd.parameters == ["longPeriod": "26", "shortPeriod": "12", "signalPeriod": "9"])
}
```

- [ ] **Step 2: Run the failing test target**

Run:

```bash
swift test --filter 'indicatorIDSupportsStringLiteralAndRawValue|builtInIndicatorMapsToStableOpenID|builtInIndicatorKeysMapToStableSeriesKeys'
```

Expected: FAIL because `IndicatorID`, `SeriesKey`, and mapping properties do not exist. If it fails earlier with `no such module 'UIKit'`, record that as the current SwiftPM limitation and continue with the implementation plus iOS build gate.

- [ ] **Step 3: Add identity types**

Create `Sources/SwiftKLine/API/KLineIndicatorIdentity.swift`:

```swift
import Foundation

public struct IndicatorID: Hashable, Sendable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }

    public var description: String {
        rawValue
    }
}

public struct SeriesKey: Hashable, Sendable, CustomStringConvertible {
    public let indicatorID: IndicatorID
    public let name: String
    public let parameters: [String: String]

    public init(
        indicatorID: IndicatorID,
        name: String,
        parameters: [String: String] = [:]
    ) {
        self.indicatorID = indicatorID
        self.name = name
        self.parameters = parameters
    }

    public var description: String {
        guard !parameters.isEmpty else {
            return "\(indicatorID).\(name)"
        }
        let parameterDescription = parameters
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ",")
        return "\(indicatorID).\(name)(\(parameterDescription))"
    }
}

public enum IndicatorPlacement: Sendable, Equatable {
    case main
    case sub
    case overlay
}

public enum RendererPlacement: Sendable, Equatable {
    case main
    case sub(IndicatorID)
    case overlay
    case crosshair
}
```

- [ ] **Step 4: Add built-in compatibility mappings**

Modify `Sources/SwiftKLine/Indicator/Indicator.swift` by adding this extension at the end:

```swift
public extension Indicator {
    var kLineID: IndicatorID {
        IndicatorID("builtin.\(rawValue.lowercased())")
    }
}

public extension Indicator.Key {
    var kLineSeriesKey: SeriesKey {
        switch self {
        case let .ma(period):
            return SeriesKey(indicatorID: Indicator.ma.kLineID, name: "MA", parameters: ["period": "\(period)"])
        case let .ema(period):
            return SeriesKey(indicatorID: Indicator.ema.kLineID, name: "EMA", parameters: ["period": "\(period)"])
        case let .wma(period):
            return SeriesKey(indicatorID: Indicator.wma.kLineID, name: "WMA", parameters: ["period": "\(period)"])
        case let .boll(period, k):
            return SeriesKey(indicatorID: Indicator.boll.kLineID, name: "BOLL", parameters: ["k": "\(k)", "period": "\(period)"])
        case .sar:
            return SeriesKey(indicatorID: Indicator.sar.kLineID, name: "SAR")
        case .vol:
            return SeriesKey(indicatorID: Indicator.vol.kLineID, name: "VOL")
        case let .rsi(period):
            return SeriesKey(indicatorID: Indicator.rsi.kLineID, name: "RSI", parameters: ["period": "\(period)"])
        case let .macd(shortPeriod, longPeriod, signalPeriod):
            return SeriesKey(
                indicatorID: Indicator.macd.kLineID,
                name: "MACD",
                parameters: [
                    "longPeriod": "\(longPeriod)",
                    "shortPeriod": "\(shortPeriod)",
                    "signalPeriod": "\(signalPeriod)"
                ]
            )
        }
    }
}
```

- [ ] **Step 5: Verify and commit**

Run:

```bash
xcodebuild -project SwiftKLineExample.xcodeproj -scheme SwiftKLineExample -destination 'generic/platform=iOS' -derivedDataPath /tmp/swiftkline-deriveddata build CODE_SIGNING_ALLOWED=NO
```

Expected: BUILD SUCCEEDED. If the environment blocks Xcode caches or package resolution, record the exact error in the task notes.

Commit:

```bash
git add Sources/SwiftKLine/API/KLineIndicatorIdentity.swift Sources/SwiftKLine/Indicator/Indicator.swift Tests/SwiftKLineTests/ArchitectureRefactorTests.swift
git commit -m "feat: add open indicator identity types"
```

## Task 2: Add Facade Chart Configuration

**Files:**
- Create: `Sources/SwiftKLine/API/ChartConfiguration.swift`
- Modify: `Sources/SwiftKLine/View/KLineView.swift`
- Test: `Tests/SwiftKLineTests/ArchitectureRefactorTests.swift`

- [ ] **Step 1: Write failing facade tests**

Append:

```swift
@Test @MainActor func chartConfigurationThemeBuildsAppearanceConfiguration() {
    let chart = ChartConfiguration(
        data: .deferred,
        appearance: .theme(.midnight),
        content: .candlestick,
        indicators: .init(main: [.builtIn(.ma)], sub: [.builtIn(.vol)]),
        features: [.liveUpdates, .gapRecovery, .indicatorPersistence],
        plugins: .default
    )

    #expect(chart.resolvedConfiguration.watermarkText == "SwiftKLine • Midnight")
    #expect(chart.content == .candlestick)
    #expect(chart.indicators.main == [.builtIn(.ma)])
    #expect(chart.features.contains(.liveUpdates))
}
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
swift test --filter chartConfigurationThemeBuildsAppearanceConfiguration
```

Expected: FAIL because `ChartConfiguration` and related types do not exist. If SwiftPM fails on UIKit, use the iOS build gate after implementation.

- [ ] **Step 3: Implement facade configuration types**

Create `Sources/SwiftKLine/API/ChartConfiguration.swift`:

```swift
import Foundation

@MainActor
public struct ChartConfiguration {
    public var data: DataSourceConfiguration
    public var appearance: KLineAppearanceConfiguration
    public var content: KLineChartContentStyle
    public var indicators: IndicatorSelectionConfiguration
    public var features: ChartFeatures
    public var plugins: PluginRegistry

    public init(
        data: DataSourceConfiguration = .deferred,
        appearance: KLineAppearanceConfiguration = .configuration(KLineConfiguration()),
        content: KLineChartContentStyle = .candlestick,
        indicators: IndicatorSelectionConfiguration = .init(),
        features: ChartFeatures = .default,
        plugins: PluginRegistry = .default
    ) {
        self.data = data
        self.appearance = appearance
        self.content = content
        self.indicators = indicators
        self.features = features
        self.plugins = plugins
    }

    @MainActor public var resolvedConfiguration: KLineConfiguration {
        appearance.resolvedConfiguration
    }
}

public enum DataSourceConfiguration {
    case provider(any KLineItemProvider)
    case deferred
}

@MainActor
public enum KLineAppearanceConfiguration {
    case configuration(KLineConfiguration)
    case theme(KLineConfiguration.ThemePreset)

    var resolvedConfiguration: KLineConfiguration {
        switch self {
        case let .configuration(configuration):
            return configuration
        case let .theme(preset):
            return .themed(preset)
        }
    }
}

public enum IndicatorSelection: Hashable, Sendable {
    case builtIn(Indicator)
    case custom(IndicatorID)
}

public struct IndicatorSelectionConfiguration: Equatable, Sendable {
    public var main: [IndicatorSelection]
    public var sub: [IndicatorSelection]

    public init(
        main: [IndicatorSelection] = [],
        sub: [IndicatorSelection] = []
    ) {
        self.main = main
        self.sub = sub
    }
}

public struct ChartFeatures: OptionSet, Sendable {
    public let rawValue: Int

    public static let liveUpdates = ChartFeatures(rawValue: 1 << 0)
    public static let gapRecovery = ChartFeatures(rawValue: 1 << 1)
    public static let indicatorPersistence = ChartFeatures(rawValue: 1 << 2)
    public static let `default`: ChartFeatures = [.liveUpdates, .gapRecovery, .indicatorPersistence]

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}
```

- [ ] **Step 4: Add new KLineView initializer without changing behavior**

Modify `Sources/SwiftKLine/View/KLineView.swift` by adding a convenience initializer after the existing initializer:

```swift
public convenience init(
    frame: CGRect = .zero,
    chart: ChartConfiguration,
    indicatorSelectionStore: IndicatorSelectionStore? = UserDefaultsIndicatorSelectionStore()
) {
    self.init(
        frame: frame,
        configuration: chart.resolvedConfiguration,
        indicatorSelectionStore: chart.features.contains(.indicatorPersistence) ? indicatorSelectionStore : nil
    )
    setChartContentStyle(chart.content)
    if case let .provider(provider) = chart.data {
        loadData(using: provider)
    }
}
```

- [ ] **Step 5: Verify and commit**

Run:

```bash
xcodebuild -project SwiftKLineExample.xcodeproj -scheme SwiftKLineExample -destination 'generic/platform=iOS' -derivedDataPath /tmp/swiftkline-deriveddata build CODE_SIGNING_ALLOWED=NO
```

Commit:

```bash
git add Sources/SwiftKLine/API/ChartConfiguration.swift Sources/SwiftKLine/View/KLineView.swift Tests/SwiftKLineTests/ArchitectureRefactorTests.swift
git commit -m "feat: add chart facade configuration"
```

## Task 3: Introduce Plugin Protocols And Registry

**Files:**
- Create: `Sources/SwiftKLine/Indicator/KLineIndicatorPlugin.swift`
- Create: `Sources/SwiftKLine/API/PluginRegistry.swift`
- Test: `Tests/SwiftKLineTests/ArchitectureRefactorTests.swift`

- [ ] **Step 1: Write failing plugin registry tests**

Append:

```swift
private struct TestScalarCalculator: KLineIndicatorCalculator {
    let id = SeriesKey(indicatorID: "test.scalar", name: "TEST")

    func calculate(for items: [any KLineItem]) -> [Double?] {
        items.map { Optional($0.closing) }
    }
}

private struct TestIndicatorPlugin: KLineIndicatorPlugin {
    let id: IndicatorID = "test.scalar"
    let title = "TEST"
    let placement: IndicatorPlacement = .sub
    let defaultSeriesKeys = [SeriesKey(indicatorID: "test.scalar", name: "TEST")]

    func makeCalculators(configuration: KLineConfiguration) -> [any KLineIndicatorCalculator] {
        [TestScalarCalculator()]
    }

    @MainActor func makeRenderers(configuration: KLineConfiguration) -> [any Renderer] {
        []
    }
}

@Test @MainActor func pluginRegistryStoresPluginsPerInstance() {
    let first = PluginRegistry()
    let second = PluginRegistry()

    first.register(TestIndicatorPlugin())

    #expect(first.plugin(for: "test.scalar") != nil)
    #expect(second.plugin(for: "test.scalar") == nil)
}
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
swift test --filter pluginRegistryStoresPluginsPerInstance
```

Expected: FAIL because plugin protocols and registry do not exist.

- [ ] **Step 3: Implement plugin protocols**

Create `Sources/SwiftKLine/Indicator/KLineIndicatorPlugin.swift`:

```swift
import Foundation

public protocol KLineIndicatorCalculator: Sendable {
    associatedtype Value: Sendable

    var id: SeriesKey { get }
    func calculate(for items: [any KLineItem]) -> [Value?]
}

public protocol KLineIndicatorPlugin: Sendable {
    var id: IndicatorID { get }
    var title: String { get }
    var placement: IndicatorPlacement { get }
    var defaultSeriesKeys: [SeriesKey] { get }

    func makeCalculators(configuration: KLineConfiguration) -> [any KLineIndicatorCalculator]
    @MainActor func makeRenderers(configuration: KLineConfiguration) -> [any Renderer]
}

struct AnyKLineIndicatorCalculator: Sendable {
    let id: SeriesKey
    private let calculateValues: @Sendable ([any KLineItem]) -> AnyIndicatorSeries

    init<C: KLineIndicatorCalculator>(_ calculator: C) {
        id = calculator.id
        calculateValues = { items in
            AnyIndicatorSeries(key: calculator.id, values: ContiguousArray(calculator.calculate(for: items)))
        }
    }

    func calculateStore(items: [any KLineItem]) -> IndicatorSeriesStore {
        var store = IndicatorSeriesStore()
        store.setSeries(calculateValues(items), for: id)
        return store
    }
}
```

- [ ] **Step 4: Implement registry**

Create `Sources/SwiftKLine/API/PluginRegistry.swift`:

```swift
import Foundation

public typealias KLineRendererProvider = @MainActor (
    RendererPlacement,
    KLineConfiguration
) -> [any Renderer]

@MainActor public final class PluginRegistry {
    public static var `default`: PluginRegistry {
        let registry = PluginRegistry()
        registry.registerBuiltInPlugins()
        return registry
    }

    private var pluginsByID: [IndicatorID: any KLineIndicatorPlugin] = [:]
    private var rendererProviders: [RendererPlacement: [KLineRendererProvider]] = [:]

    public init() {}

    public func register(_ plugin: any KLineIndicatorPlugin) {
        pluginsByID[plugin.id] = plugin
    }

    public func plugin(for id: IndicatorID) -> (any KLineIndicatorPlugin)? {
        pluginsByID[id]
    }

    public func plugins(for placement: IndicatorPlacement) -> [any KLineIndicatorPlugin] {
        pluginsByID.values.filter { $0.placement == placement }
    }

    public func registerRenderer(
        placement: RendererPlacement,
        provider: @escaping KLineRendererProvider
    ) {
        rendererProviders[placement, default: []].append(provider)
    }

    func renderers(
        for placement: RendererPlacement,
        configuration: KLineConfiguration
    ) -> [AnyRenderer] {
        rendererProviders[placement, default: []]
            .flatMap { $0(placement, configuration) }
            .map { $0.eraseToAnyRenderer() }
    }

    private func registerBuiltInPlugins() {
    }
}
```

- [ ] **Step 5: Verify and commit**

Run the iOS build gate. Commit:

```bash
git add Sources/SwiftKLine/Indicator/KLineIndicatorPlugin.swift Sources/SwiftKLine/API/PluginRegistry.swift Tests/SwiftKLineTests/ArchitectureRefactorTests.swift
git commit -m "feat: add indicator plugin registry"
```

## Task 4: Migrate IndicatorSeriesStore To Open Keys

**Files:**
- Modify: `Sources/SwiftKLine/Data/IndicatorSeriesStore.swift`
- Modify: `Sources/SwiftKLine/Data/RendererContext.swift`
- Modify: `Sources/SwiftKLine/Calculator/IndicatorCalculator.swift`
- Test: `Tests/SwiftKLineTests/ArchitectureRefactorTests.swift`

- [ ] **Step 1: Write failing series-store tests**

Append:

```swift
@Test func indicatorSeriesStoreStoresAndReadsOpenKeySeries() {
    var store = IndicatorSeriesStore()
    let key = SeriesKey(indicatorID: "test.scalar", name: "TEST")

    store.setValues(ContiguousArray<Double?>([1, nil, 3]), for: key)

    let values = store.values(for: key, as: Double.self)
    #expect(values == ContiguousArray<Double?>([1, nil, 3]))
}

@Test func legacyIndicatorSeriesStillUsesCompatibilityKeys() {
    var store = IndicatorSeriesStore()
    store.scalarSeries[.ma(5)] = ContiguousArray<Double?>([1, 2, 3])

    let values = store.values(for: Indicator.Key.ma(5).kLineSeriesKey, as: Double.self)
    #expect(values == ContiguousArray<Double?>([1, 2, 3]))
}
```

- [ ] **Step 2: Run the failing tests**

Run:

```bash
swift test --filter 'indicatorSeriesStoreStoresAndReadsOpenKeySeries|legacyIndicatorSeriesStillUsesCompatibilityKeys'
```

Expected: FAIL because open-key series APIs do not exist.

- [ ] **Step 3: Implement type-erased series storage**

Replace `Sources/SwiftKLine/Data/IndicatorSeriesStore.swift` with:

```swift
import Foundation

struct AnyIndicatorSeries {
    let key: SeriesKey
    private let valuesStorage: Any

    init<Value>(key: SeriesKey, values: ContiguousArray<Value?>) {
        self.key = key
        valuesStorage = values
    }

    func values<Value>(as type: Value.Type) -> ContiguousArray<Value?>? {
        valuesStorage as? ContiguousArray<Value?>
    }
}

struct IndicatorSeriesStore {
    private var series: [SeriesKey: AnyIndicatorSeries] = [:]

    var scalarSeries: [Indicator.Key: ContiguousArray<Double?>] {
        get {
            Dictionary(uniqueKeysWithValues: series.compactMap { key, value in
                guard let legacyKey = key.legacyIndicatorKey,
                      let values = value.values(as: Double.self) else {
                    return nil
                }
                return (legacyKey, values)
            })
        }
        set {
            for (key, values) in newValue {
                setValues(values, for: key.kLineSeriesKey)
            }
        }
    }

    var bollSeries: [Indicator.Key: ContiguousArray<BOLLIndicatorValue?>] {
        get {
            Dictionary(uniqueKeysWithValues: series.compactMap { key, value in
                guard let legacyKey = key.legacyIndicatorKey,
                      let values = value.values(as: BOLLIndicatorValue.self) else {
                    return nil
                }
                return (legacyKey, values)
            })
        }
        set {
            for (key, values) in newValue {
                setValues(values, for: key.kLineSeriesKey)
            }
        }
    }

    var macdSeries: [Indicator.Key: ContiguousArray<MACDIndicatorValue?>] {
        get {
            Dictionary(uniqueKeysWithValues: series.compactMap { key, value in
                guard let legacyKey = key.legacyIndicatorKey,
                      let values = value.values(as: MACDIndicatorValue.self) else {
                    return nil
                }
                return (legacyKey, values)
            })
        }
        set {
            for (key, values) in newValue {
                setValues(values, for: key.kLineSeriesKey)
            }
        }
    }

    mutating func setSeries(_ value: AnyIndicatorSeries, for key: SeriesKey) {
        series[key] = value
    }

    mutating func setValues<Value>(_ values: ContiguousArray<Value?>, for key: SeriesKey) {
        series[key] = AnyIndicatorSeries(key: key, values: values)
    }

    func values<Value>(for key: SeriesKey, as type: Value.Type) -> ContiguousArray<Value?>? {
        series[key]?.values(as: type)
    }

    mutating func merge(_ other: IndicatorSeriesStore) {
        series.merge(other.series) { _, new in new }
    }
}
```

- [ ] **Step 4: Add legacy reverse mapping**

Append to `Sources/SwiftKLine/API/KLineIndicatorIdentity.swift`:

```swift
extension SeriesKey {
    var legacyIndicatorKey: Indicator.Key? {
        switch indicatorID.rawValue {
        case "builtin.ma":
            return intParameter("period").map(Indicator.Key.ma)
        case "builtin.ema":
            return intParameter("period").map(Indicator.Key.ema)
        case "builtin.wma":
            return intParameter("period").map(Indicator.Key.wma)
        case "builtin.boll":
            guard let period = intParameter("period"),
                  let k = doubleParameter("k") else { return nil }
            return .boll(period: period, k: k)
        case "builtin.sar":
            return .sar
        case "builtin.vol":
            return .vol
        case "builtin.rsi":
            return intParameter("period").map(Indicator.Key.rsi)
        case "builtin.macd":
            guard let short = intParameter("shortPeriod"),
                  let long = intParameter("longPeriod"),
                  let signal = intParameter("signalPeriod") else { return nil }
            return .macd(shortPeriod: short, longPeriod: long, signalPeriod: signal)
        default:
            return nil
        }
    }

    private func intParameter(_ name: String) -> Int? {
        parameters[name].flatMap(Int.init)
    }

    private func doubleParameter(_ name: String) -> Double? {
        parameters[name].flatMap(Double.init)
    }
}
```

- [ ] **Step 5: Add RendererContext open-key reader**

Append to `Sources/SwiftKLine/Data/RendererContext.swift`:

```swift
public extension RendererContext {
    func values<Value>(
        for key: SeriesKey,
        as type: Value.Type
    ) -> ContiguousArray<Value?>? {
        indicatorSeriesStore.values(for: key, as: type)
    }
}
```

- [ ] **Step 6: Verify and commit**

Run the iOS build gate. Commit:

```bash
git add Sources/SwiftKLine/Data/IndicatorSeriesStore.swift Sources/SwiftKLine/Data/RendererContext.swift Sources/SwiftKLine/API/KLineIndicatorIdentity.swift Tests/SwiftKLineTests/ArchitectureRefactorTests.swift
git commit -m "refactor: store indicator series by open keys"
```

## Task 5: Bridge Existing Calculators To Public Calculators

**Files:**
- Modify: `Sources/SwiftKLine/Calculator/IndicatorCalculator.swift`
- Modify: `Sources/SwiftKLine/Calculator/IndicatorCalculationEngine.swift`
- Modify: `Sources/SwiftKLine/Utils/Sequence+IndicatorCalculation.swift`
- Test: `Tests/SwiftKLineTests/ArchitectureRefactorTests.swift`

- [ ] **Step 1: Write failing calculator bridge test**

Append:

```swift
@Test func legacyMACalculatorWritesOpenSeriesKey() async {
    let items: [any KLineItem] = [
        TestKLineItem(timestamp: 1, closing: 1),
        TestKLineItem(timestamp: 2, closing: 2),
        TestKLineItem(timestamp: 3, closing: 3)
    ]

    let store = await [MACalculator(period: 2).eraseToAnyKLineIndicatorCalculator()].calculate(items: items)
    let values = store.values(for: Indicator.Key.ma(2).kLineSeriesKey, as: Double.self)

    #expect(values?[0] == nil)
    #expect(values?[1] == 1.5)
    #expect(values?[2] == 2.5)
}
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
swift test --filter legacyMACalculatorWritesOpenSeriesKey
```

Expected: FAIL because calculator type erasure is not bridged.

- [ ] **Step 3: Bridge legacy calculators**

Modify `Sources/SwiftKLine/Calculator/IndicatorCalculator.swift`:

```swift
extension IndicatorCalculator {
    var seriesKey: SeriesKey {
        key.kLineSeriesKey
    }

    func eraseToAnyKLineIndicatorCalculator() -> AnyKLineIndicatorCalculator {
        LegacyIndicatorCalculatorAdapter(self).eraseToAnyKLineIndicatorCalculator()
    }
}

private struct LegacyIndicatorCalculatorAdapter<Base: IndicatorCalculator>: KLineIndicatorCalculator {
    let base: Base

    init(_ base: Base) {
        self.base = base
    }

    var id: SeriesKey {
        base.key.kLineSeriesKey
    }

    func calculate(for items: [any KLineItem]) -> [Base.Result?] {
        base.calculate(for: items)
    }
}

extension KLineIndicatorCalculator {
    func eraseToAnyKLineIndicatorCalculator() -> AnyKLineIndicatorCalculator {
        AnyKLineIndicatorCalculator(self)
    }
}
```

- [ ] **Step 4: Update sequence calculation to support new type erasure**

Add to `Sources/SwiftKLine/Utils/Sequence+IndicatorCalculation.swift`:

```swift
extension Sequence where Element == AnyKLineIndicatorCalculator {
    func calculate(items: [any KLineItem]) async -> IndicatorSeriesStore {
        await withTaskGroup(of: IndicatorSeriesStore.self) { group in
            for calculator in self {
                group.addTask {
                    calculator.calculateStore(items: items)
                }
            }

            var store = IndicatorSeriesStore()
            for await partialStore in group {
                store.merge(partialStore)
            }
            return store
        }
    }
}
```

- [ ] **Step 5: Keep existing engine API working**

Modify `Sources/SwiftKLine/Calculator/IndicatorCalculationEngine.swift` so the `calculators` overload erases legacy calculators:

```swift
func calculate(
    items: [any KLineItem],
    calculators: [any IndicatorCalculator]
) async -> IndicatorSeriesStore {
    guard !calculators.isEmpty else { return IndicatorSeriesStore() }
    let erased = calculators.map { $0.eraseToAnyKLineIndicatorCalculator() }
    return await erased.calculate(items: items)
}
```

- [ ] **Step 6: Verify and commit**

Run the iOS build gate. Commit:

```bash
git add Sources/SwiftKLine/Calculator/IndicatorCalculator.swift Sources/SwiftKLine/Calculator/IndicatorCalculationEngine.swift Sources/SwiftKLine/Utils/Sequence+IndicatorCalculation.swift Tests/SwiftKLineTests/ArchitectureRefactorTests.swift
git commit -m "refactor: bridge legacy calculators to open series"
```

## Task 6: Add Built-In Indicator Plugins

**Files:**
- Create: `Sources/SwiftKLine/Indicator/BuiltInIndicatorPlugins.swift`
- Modify: `Sources/SwiftKLine/API/PluginRegistry.swift`
- Modify: `Sources/SwiftKLine/Indicator/IndicatorCatalog.swift`
- Test: `Tests/SwiftKLineTests/ArchitectureRefactorTests.swift`

- [ ] **Step 1: Write failing built-in plugin tests**

Append:

```swift
@Test @MainActor func defaultRegistryContainsBuiltInPlugins() {
    let registry = PluginRegistry.default

    #expect(registry.plugin(for: Indicator.ma.kLineID) != nil)
    #expect(registry.plugin(for: Indicator.macd.kLineID) != nil)
}

@Test @MainActor func builtInMAPluginCreatesCalculatorsAndRenderers() {
    let plugin = PluginRegistry.default.plugin(for: Indicator.ma.kLineID)
    let configuration = KLineConfiguration()

    #expect(plugin?.defaultSeriesKeys == Indicator.ma.defaultKeys.map(\.kLineSeriesKey))
    #expect(plugin?.makeCalculators(configuration: configuration).isEmpty == false)
    #expect(plugin?.makeRenderers(configuration: configuration).isEmpty == false)
}
```

- [ ] **Step 2: Run the failing tests**

Run:

```bash
swift test --filter 'defaultRegistryContainsBuiltInPlugins|builtInMAPluginCreatesCalculatorsAndRenderers'
```

Expected: FAIL because default registry does not register built-ins.

- [ ] **Step 3: Implement built-in plugin wrapper**

Create `Sources/SwiftKLine/Indicator/BuiltInIndicatorPlugins.swift`:

```swift
import Foundation

@MainActor
struct BuiltInIndicatorPlugin: KLineIndicatorPlugin {
    let indicator: Indicator

    var id: IndicatorID {
        indicator.kLineID
    }

    var title: String {
        indicator.rawValue
    }

    var placement: IndicatorPlacement {
        indicator.isMain ? .main : .sub
    }

    var defaultSeriesKeys: [SeriesKey] {
        indicator.defaultKeys.map(\.kLineSeriesKey)
    }

    func makeCalculators(configuration: KLineConfiguration) -> [any KLineIndicatorCalculator] {
        indicator
            .makeCalculators(configuration: configuration)
            .map { $0.eraseToAnyKLineIndicatorCalculator() }
    }

    func makeRenderers(configuration: KLineConfiguration) -> [any Renderer] {
        guard let renderer = IndicatorCatalog.spec(for: indicator)?.makeRenderer(configuration: configuration) else {
            return []
        }
        return [renderer]
    }
}
```

- [ ] **Step 4: Register built-ins in default registry**

Modify `registerBuiltInPlugins()` in `Sources/SwiftKLine/API/PluginRegistry.swift`:

```swift
private func registerBuiltInPlugins() {
    for indicator in Indicator.allCases {
        register(BuiltInIndicatorPlugin(indicator: indicator))
    }
}
```

- [ ] **Step 5: Verify and commit**

Run the iOS build gate. Commit:

```bash
git add Sources/SwiftKLine/Indicator/BuiltInIndicatorPlugins.swift Sources/SwiftKLine/API/PluginRegistry.swift Tests/SwiftKLineTests/ArchitectureRefactorTests.swift
git commit -m "feat: register built-in indicator plugins"
```

## Task 7: Extract Chart State And Data Pipeline

**Files:**
- Create: `Sources/SwiftKLine/Data/KLineChartState.swift`
- Create: `Sources/SwiftKLine/Data/KLineDataPipeline.swift`
- Modify: `Sources/SwiftKLine/View/KLineView.swift`
- Test: `Tests/SwiftKLineTests/ArchitectureRefactorTests.swift`

- [ ] **Step 1: Write failing data pipeline tests**

Append:

```swift
@Test func chartStateDefaultsAreEmptyAndCandlestick() {
    let state = KLineChartState()

    #expect(state.items.isEmpty)
    #expect(state.contentStyle == .candlestick)
    #expect(state.selectedIndex == nil)
    #expect(state.lastError == nil)
}

@Test func dataPipelineMergesHistoricalPageIntoState() async {
    let pipeline = KLineDataPipeline()
    var state = KLineChartState()
    let items: [any KLineItem] = [
        TestKLineItem(timestamp: 60, closing: 1),
        TestKLineItem(timestamp: 120, closing: 2)
    ]

    await pipeline.apply(.page(index: 0, items: items), to: &state)

    #expect(state.items.map(\.timestamp) == [60, 120])
}

@Test func dataPipelineMergesLiveTickIntoState() async {
    let pipeline = KLineDataPipeline()
    var state = KLineChartState(items: [
        TestKLineItem(timestamp: 60, closing: 1),
        TestKLineItem(timestamp: 120, closing: 2)
    ])

    await pipeline.apply(.liveTick(TestKLineItem(timestamp: 120, closing: 22)), to: &state)

    #expect(state.items.map(\.closing) == [1, 22])
}
```

- [ ] **Step 2: Run the failing tests**

Run:

```bash
swift test --filter 'chartStateDefaultsAreEmptyAndCandlestick|dataPipelineMergesHistoricalPageIntoState|dataPipelineMergesLiveTickIntoState'
```

Expected: FAIL because state and pipeline do not exist.

- [ ] **Step 3: Add chart state**

Create `Sources/SwiftKLine/Data/KLineChartState.swift`:

```swift
import Foundation

struct KLineChartState {
    var items: [any KLineItem]
    var indicatorSeriesStore: IndicatorSeriesStore
    var contentStyle: KLineChartContentStyle
    var selectedIndex: Int?
    var selectedLocation: CGPoint?
    var lastError: Error?
    var mainIndicators: [Indicator]
    var subIndicators: [Indicator]

    init(
        items: [any KLineItem] = [],
        indicatorSeriesStore: IndicatorSeriesStore = IndicatorSeriesStore(),
        contentStyle: KLineChartContentStyle = .candlestick,
        selectedIndex: Int? = nil,
        selectedLocation: CGPoint? = nil,
        lastError: Error? = nil,
        mainIndicators: [Indicator] = [],
        subIndicators: [Indicator] = []
    ) {
        self.items = items
        self.indicatorSeriesStore = indicatorSeriesStore
        self.contentStyle = contentStyle
        self.selectedIndex = selectedIndex
        self.selectedLocation = selectedLocation
        self.lastError = lastError
        self.mainIndicators = mainIndicators
        self.subIndicators = subIndicators
    }
}
```

Add `import CoreGraphics` if `CGPoint` is not available through existing imports.

- [ ] **Step 4: Add data pipeline**

Create `Sources/SwiftKLine/Data/KLineDataPipeline.swift`:

```swift
import Foundation

struct KLineDataPipeline {
    private var dataMerger = KLineDataMerger()

    mutating func reset() {
        dataMerger.reset()
    }

    mutating func apply(_ event: DataLoaderEvent, to state: inout KLineChartState) async {
        switch event {
        case let .page(index, items):
            if index == 0 {
                dataMerger.prepareBucketsIfNeeded(with: items)
                state.items = items
            } else {
                state.items = dataMerger.merge(current: state.items, patch: items)
            }
        case let .recovery(items):
            state.items = dataMerger.merge(current: state.items, patch: items)
        case let .liveTick(tick):
            _ = dataMerger.applyLiveTick(tick, to: &state.items)
        case let .failed(error):
            state.lastError = error
        }
    }
}
```

- [ ] **Step 5: Integrate minimally into KLineView**

Modify `Sources/SwiftKLine/View/KLineView.swift`:

- Add `private var chartState = KLineChartState()`
- Add `private var dataPipeline = KLineDataPipeline()`
- In reset logic inside `loadData(using:)`, reset `chartState`, `dataPipeline`, and keep assigning legacy fields for this phase.
- In `handleLoaderEvent(_:)`, call the pipeline first, then copy `chartState.items` into `klineItems` before existing draw calls. Preserve existing behavior in this task; do not remove old fields yet.

Use this helper inside `KLineView`:

```swift
private func synchronizeLegacyStateFromChartState() {
    klineItems = chartState.items
}
```

- [ ] **Step 6: Verify and commit**

Run the iOS build gate. Commit:

```bash
git add Sources/SwiftKLine/Data/KLineChartState.swift Sources/SwiftKLine/Data/KLineDataPipeline.swift Sources/SwiftKLine/View/KLineView.swift Tests/SwiftKLineTests/ArchitectureRefactorTests.swift
git commit -m "refactor: introduce chart state and data pipeline"
```

## Task 8: Extract Indicator Pipeline

**Files:**
- Create: `Sources/SwiftKLine/Data/KLineIndicatorPipeline.swift`
- Modify: `Sources/SwiftKLine/View/KLineView.swift`
- Modify: `Sources/SwiftKLine/Calculator/IndicatorCalculationEngine.swift`
- Test: `Tests/SwiftKLineTests/ArchitectureRefactorTests.swift`

- [ ] **Step 1: Write failing indicator pipeline tests**

Append:

```swift
@Test @MainActor func indicatorPipelineNormalizesAndPersistsSelection() {
    let normalizer = IndicatorSelectionNormalizer(availableMain: [.ma, .ema], availableSub: [.vol])
    let store = InMemoryIndicatorSelectionStore()
    var pipeline = KLineIndicatorPipeline(
        configuration: KLineConfiguration(defaultMainIndicators: [.ma], defaultSubIndicators: [.vol]),
        normalizer: normalizer,
        selectionStore: store,
        registry: .default
    )

    let state = pipeline.setSelection(main: [.ma, .vol, .ema], sub: [.ema, .vol])

    #expect(state.mainIndicators == [.ma, .ema])
    #expect(state.subIndicators == [.vol])
    #expect(store.savedState == state)
}
```

Add this test helper in the same file:

```swift
private final class InMemoryIndicatorSelectionStore: IndicatorSelectionStore {
    var savedState: IndicatorSelectionState?

    func load() -> IndicatorSelectionState? {
        savedState
    }

    func save(state: IndicatorSelectionState) {
        savedState = state
    }

    func reset() {
        savedState = nil
    }
}
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
swift test --filter indicatorPipelineNormalizesAndPersistsSelection
```

Expected: FAIL because `KLineIndicatorPipeline` does not exist.

- [ ] **Step 3: Implement indicator pipeline**

Create `Sources/SwiftKLine/Data/KLineIndicatorPipeline.swift`:

```swift
import Foundation

@MainActor
struct KLineIndicatorPipeline {
    private let configuration: KLineConfiguration
    private let normalizer: IndicatorSelectionNormalizer
    private let selectionStore: IndicatorSelectionStore?
    private let registry: PluginRegistry
    private let calculationEngine = IndicatorCalculationEngine()

    init(
        configuration: KLineConfiguration,
        normalizer: IndicatorSelectionNormalizer,
        selectionStore: IndicatorSelectionStore?,
        registry: PluginRegistry
    ) {
        self.configuration = configuration
        self.normalizer = normalizer
        self.selectionStore = selectionStore
        self.registry = registry
    }

    func initialSelection() -> IndicatorSelectionState {
        normalizer.normalize(selectionStore?.load())
    }

    func setSelection(main: [Indicator], sub: [Indicator]) -> IndicatorSelectionState {
        let normalized = normalizer.normalize(
            IndicatorSelectionState(mainIndicators: main, subIndicators: sub)
        )
        selectionStore?.save(state: normalized)
        return normalized
    }

    func resetSelection() -> IndicatorSelectionState {
        selectionStore?.reset()
        let state = IndicatorSelectionState(
            mainIndicators: configuration.defaultMainIndicators,
            subIndicators: configuration.defaultSubIndicators
        )
        selectionStore?.save(state: state)
        return state
    }

    func calculate(
        items: [any KLineItem],
        mainIndicators: [Indicator],
        subIndicators: [Indicator]
    ) async -> IndicatorSeriesStore {
        await calculationEngine.calculate(
            items: items,
            mainIndicators: mainIndicators,
            subIndicators: subIndicators,
            configuration: configuration
        )
    }
}
```

- [ ] **Step 4: Integrate minimally into KLineView**

Modify `Sources/SwiftKLine/View/KLineView.swift`:

- Add `private var indicatorPipeline: KLineIndicatorPipeline?`
- Initialize it after `indicatorSelectionNormalizer` is created.
- Replace `saveIndicatorSelection()` internals with:

```swift
private func saveIndicatorSelection() {
    let normalized = indicatorPipeline?.setSelection(
        main: mainIndicatorTypes,
        sub: subIndicatorTypes
    ) ?? indicatorSelectionNormalizer.normalize(
        IndicatorSelectionState(
            mainIndicators: mainIndicatorTypes,
            subIndicators: subIndicatorTypes
        )
    )
    indicatorSelectionDidChange?(normalized)
}
```

- Replace `resetIndicatorsToDefault()` persistence logic with `indicatorPipeline?.resetSelection()`.
- Keep `indicatorCalculationEngine` until Task 10 removes direct view ownership.

- [ ] **Step 5: Verify and commit**

Run the iOS build gate. Commit:

```bash
git add Sources/SwiftKLine/Data/KLineIndicatorPipeline.swift Sources/SwiftKLine/View/KLineView.swift Tests/SwiftKLineTests/ArchitectureRefactorTests.swift
git commit -m "refactor: extract indicator pipeline"
```

## Task 9: Add Render Pipeline And Instance Registry Usage

**Files:**
- Create: `Sources/SwiftKLine/Renderer/KLineRenderPipeline.swift`
- Modify: `Sources/SwiftKLine/Renderer/KLineDescriptorFactory.swift`
- Modify: `Sources/SwiftKLine/View/KLineView.swift`
- Modify: `Sources/SwiftKLine/View/IndicatorRendererRegistry.swift`
- Test: `Tests/SwiftKLineTests/ArchitectureRefactorTests.swift`

- [ ] **Step 1: Write failing registry isolation test**

Append:

```swift
@MainActor private final class TestRenderer: Renderer {
    let id = "test-renderer"

    func install(to layer: CALayer) {}
    func uninstall(from layer: CALayer) {}
    func draw(in layer: CALayer, context: Context) {}
}

@Test @MainActor func renderPipelineUsesInstanceRegistry() {
    let firstRegistry = PluginRegistry.default
    let secondRegistry = PluginRegistry.default
    firstRegistry.registerRenderer(placement: .overlay) { _, _ in [TestRenderer()] }

    let factory = KLineDescriptorFactory()
    let config = KLineConfiguration()
    let first = factory.makeDescriptor(
        contentStyle: .candlestick,
        mainIndicators: [],
        subIndicators: [],
        customRenderers: [],
        configuration: config,
        layoutMetrics: config.layoutMetrics,
        registry: firstRegistry
    )
    let second = factory.makeDescriptor(
        contentStyle: .candlestick,
        mainIndicators: [],
        subIndicators: [],
        customRenderers: [],
        configuration: config,
        layoutMetrics: config.layoutMetrics,
        registry: secondRegistry
    )

    #expect(first.renderers.contains { String(describing: $0.id) == "test-renderer" })
    #expect(!second.renderers.contains { String(describing: $0.id) == "test-renderer" })
}
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
swift test --filter renderPipelineUsesInstanceRegistry
```

Expected: FAIL because descriptor factory does not accept an instance registry.

- [ ] **Step 3: Update descriptor factory signature**

Modify `Sources/SwiftKLine/Renderer/KLineDescriptorFactory.swift`:

```swift
func makeDescriptor(
    contentStyle: KLineChartContentStyle,
    mainIndicators: [Indicator],
    subIndicators: [Indicator],
    customRenderers: [AnyRenderer],
    configuration: KLineConfiguration,
    layoutMetrics: LayoutMetrics,
    registry: PluginRegistry
) -> ChartDescriptor
```

Replace each `IndicatorRendererRegistry.shared.renderers(for: type, configuration: configuration)` with:

```swift
registry.renderers(for: .sub(type.kLineID), configuration: configuration)
```

For main indicators, use `.main` plus built-in plugin renderers:

```swift
if let plugin = registry.plugin(for: type.kLineID) {
    for renderer in plugin.makeRenderers(configuration: configuration).map({ $0.eraseToAnyRenderer() }) {
        renderer
    }
}
```

Add overlay renderer injection before `YAxisRenderer()`:

```swift
for renderer in registry.renderers(for: .overlay, configuration: configuration) {
    renderer
}
```

- [ ] **Step 4: Add render pipeline wrapper**

Create `Sources/SwiftKLine/Renderer/KLineRenderPipeline.swift`:

```swift
import Foundation

@MainActor
struct KLineRenderPipeline {
    private let descriptorFactory = KLineDescriptorFactory()
    private let registry: PluginRegistry

    init(registry: PluginRegistry) {
        self.registry = registry
    }

    func makeDescriptor(
        contentStyle: KLineChartContentStyle,
        mainIndicators: [Indicator],
        subIndicators: [Indicator],
        customRenderers: [AnyRenderer],
        configuration: KLineConfiguration,
        layoutMetrics: LayoutMetrics
    ) -> ChartDescriptor {
        descriptorFactory.makeDescriptor(
            contentStyle: contentStyle,
            mainIndicators: mainIndicators,
            subIndicators: subIndicators,
            customRenderers: customRenderers,
            configuration: configuration,
            layoutMetrics: layoutMetrics,
            registry: registry
        )
    }
}
```

- [ ] **Step 5: Integrate registry into KLineView**

Modify `KLineView`:

- Add `private let pluginRegistry: PluginRegistry`
- Add `private let renderPipeline: KLineRenderPipeline`
- In old initializer, use `.default`.
- In new chart initializer, pass `chart.plugins`.
- In `updateDescriptorAndDrawContent()`, replace the direct `descriptorFactory.makeDescriptor` call with:

```swift
var newDescriptor = renderPipeline.makeDescriptor(
    contentStyle: mainChartContent,
    mainIndicators: mainIndicatorTypes,
    subIndicators: subIndicatorTypes,
    customRenderers: customRenderers,
    configuration: klineConfig,
    layoutMetrics: layoutMetrics
)
```

- [ ] **Step 6: Preserve old global registration**

Modify `IndicatorRendererRegistry` so old `KLineView.registerRenderer(for:)` stores compatibility providers. When creating `PluginRegistry.default`, merge these providers into the default registry by registering providers for `.sub(indicator.kLineID)` or `.main` based on `indicator.isMain`.

- [ ] **Step 7: Verify and commit**

Run the iOS build gate. Commit:

```bash
git add Sources/SwiftKLine/Renderer/KLineRenderPipeline.swift Sources/SwiftKLine/Renderer/KLineDescriptorFactory.swift Sources/SwiftKLine/View/KLineView.swift Sources/SwiftKLine/View/IndicatorRendererRegistry.swift Tests/SwiftKLineTests/ArchitectureRefactorTests.swift
git commit -m "refactor: use instance plugin registry for rendering"
```

## Task 10: Add Chart Controller And Reduce KLineView Ownership

**Files:**
- Create: `Sources/SwiftKLine/Data/KLineChartController.swift`
- Modify: `Sources/SwiftKLine/View/KLineView.swift`
- Test: `Tests/SwiftKLineTests/ArchitectureRefactorTests.swift`

- [ ] **Step 1: Write failing controller command tests**

Append:

```swift
@Test @MainActor func chartControllerUpdatesContentStyleCommand() {
    var controller = KLineChartController(
        state: KLineChartState(),
        dataPipeline: KLineDataPipeline(),
        indicatorPipeline: nil
    )

    controller.setChartContentStyle(.timeSeries)

    #expect(controller.state.contentStyle == .timeSeries)
}
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
swift test --filter chartControllerUpdatesContentStyleCommand
```

Expected: FAIL because controller does not exist.

- [ ] **Step 3: Implement controller**

Create `Sources/SwiftKLine/Data/KLineChartController.swift`:

```swift
import Foundation

@MainActor
struct KLineChartController {
    private(set) var state: KLineChartState
    private var dataPipeline: KLineDataPipeline
    private var indicatorPipeline: KLineIndicatorPipeline?

    init(
        state: KLineChartState = KLineChartState(),
        dataPipeline: KLineDataPipeline = KLineDataPipeline(),
        indicatorPipeline: KLineIndicatorPipeline? = nil
    ) {
        self.state = state
        self.dataPipeline = dataPipeline
        self.indicatorPipeline = indicatorPipeline
    }

    mutating func reset() {
        state = KLineChartState(
            contentStyle: state.contentStyle,
            mainIndicators: state.mainIndicators,
            subIndicators: state.subIndicators
        )
        dataPipeline.reset()
    }

    mutating func setChartContentStyle(_ style: KLineChartContentStyle) {
        state.contentStyle = style
    }

    mutating func setIndicators(main: [Indicator], sub: [Indicator]) {
        if let selection = indicatorPipeline?.setSelection(main: main, sub: sub) {
            state.mainIndicators = selection.mainIndicators
            state.subIndicators = selection.subIndicators
        } else {
            state.mainIndicators = main
            state.subIndicators = sub
        }
    }

    mutating func applyLoaderEvent(_ event: DataLoaderEvent) async {
        await dataPipeline.apply(event, to: &state)
    }

    mutating func recalculateIndicators(configuration: KLineConfiguration) async {
        guard let indicatorPipeline else { return }
        state.indicatorSeriesStore = await indicatorPipeline.calculate(
            items: state.items,
            mainIndicators: state.mainIndicators,
            subIndicators: state.subIndicators
        )
    }
}
```

- [ ] **Step 4: Move direct view state updates behind controller**

Modify `KLineView` incrementally:

- Add `private var controller: KLineChartController`
- Replace direct updates to `mainChartContent` with `controller.setChartContentStyle`.
- Replace direct indicator selection persistence with `controller.setIndicators`.
- Replace loader event state mutation with `await controller.applyLoaderEvent(event)`.
- Keep `klineItems`, `indicatorSeriesStore`, `mainIndicatorTypes`, and `subIndicatorTypes` as synchronized compatibility fields until all rendering reads are moved.

Use this helper:

```swift
private func synchronizeLegacyFieldsFromController() {
    let state = controller.state
    klineItems = state.items
    indicatorSeriesStore = state.indicatorSeriesStore
    mainChartContent = state.contentStyle
    mainIndicatorTypes = state.mainIndicators
    subIndicatorTypes = state.subIndicators
    selectedIndex = state.selectedIndex
    selectedLocation = state.selectedLocation
}
```

- [ ] **Step 5: Verify ownership reduction**

Run:

```bash
rg -n "private let indicatorCalculationEngine|private var dataMerger|private var chartState|private var dataPipeline|private var indicatorPipeline" Sources/SwiftKLine/View/KLineView.swift
```

Expected: no matches for direct business objects after this task, except `controller`, `klineItemLoader`, view/render scheduling objects, and UI state needed for drawing.

- [ ] **Step 6: Verify and commit**

Run the iOS build gate. Commit:

```bash
git add Sources/SwiftKLine/Data/KLineChartController.swift Sources/SwiftKLine/View/KLineView.swift Tests/SwiftKLineTests/ArchitectureRefactorTests.swift
git commit -m "refactor: route chart commands through controller"
```

## Task 11: Add External Custom Indicator Contract Test

**Files:**
- Modify: `Tests/SwiftKLineTests/ArchitectureRefactorTests.swift`
- Modify: production files only if the test reveals missing access level or API gaps.

- [ ] **Step 1: Add full custom indicator test**

Append:

```swift
private struct CloseEchoCalculator: KLineIndicatorCalculator {
    let id = SeriesKey(indicatorID: "custom.closeEcho", name: "CloseEcho")

    func calculate(for items: [any KLineItem]) -> [Double?] {
        items.map { Optional($0.closing) }
    }
}

private struct CloseEchoPlugin: KLineIndicatorPlugin {
    let id: IndicatorID = "custom.closeEcho"
    let title = "Close Echo"
    let placement = IndicatorPlacement.overlay
    let defaultSeriesKeys = [SeriesKey(indicatorID: "custom.closeEcho", name: "CloseEcho")]

    func makeCalculators(configuration: KLineConfiguration) -> [any KLineIndicatorCalculator] {
        [CloseEchoCalculator()]
    }

    @MainActor func makeRenderers(configuration: KLineConfiguration) -> [any Renderer] {
        [TestRenderer()]
    }
}

@Test @MainActor func externalCustomIndicatorCanBeRegisteredCalculatedAndRendered() async {
    let registry = PluginRegistry.default
    registry.register(CloseEchoPlugin())
    let plugin = registry.plugin(for: "custom.closeEcho")
    let items: [any KLineItem] = [
        TestKLineItem(timestamp: 1, closing: 10),
        TestKLineItem(timestamp: 2, closing: 11)
    ]

    let calculators = plugin?.makeCalculators(configuration: KLineConfiguration()).map {
        $0.eraseToAnyKLineIndicatorCalculator()
    } ?? []
    let store = await calculators.calculate(items: items)
    let values = store.values(for: SeriesKey(indicatorID: "custom.closeEcho", name: "CloseEcho"), as: Double.self)

    #expect(values == ContiguousArray<Double?>([10, 11]))
    #expect(plugin?.makeRenderers(configuration: KLineConfiguration()).isEmpty == false)
}
```

- [ ] **Step 2: Run the contract test**

Run:

```bash
swift test --filter externalCustomIndicatorCanBeRegisteredCalculatedAndRendered
```

Expected after prior tasks: PASS under an iOS-capable test runner. If SwiftPM still fails on UIKit, verify with the iOS build gate and inspect compile errors for access-level problems.

- [ ] **Step 3: Fix access-level gaps discovered by the test**

If the test cannot compile because public protocols or type-erasure APIs are internal, make these APIs public:

```swift
public extension KLineIndicatorCalculator {
    func eraseToAnyKLineIndicatorCalculator() -> AnyKLineIndicatorCalculator {
        AnyKLineIndicatorCalculator(self)
    }
}
```

Make `AnyKLineIndicatorCalculator` public only if external users need to pass erased calculators directly. If it remains an internal implementation detail, keep plugin return type as `[any KLineIndicatorCalculator]` and perform erasure inside framework pipelines.

- [ ] **Step 4: Verify and commit**

Run the iOS build gate. Commit:

```bash
git add Tests/SwiftKLineTests/ArchitectureRefactorTests.swift Sources/SwiftKLine
git commit -m "test: cover external custom indicator plugins"
```

## Task 12: Update Example App To Use New Facade API

**Files:**
- Modify: `SwiftKLineExample/KLineSwiftUIView.swift`
- Test: iOS build gate.

- [ ] **Step 1: Change example construction**

Modify `makeUIView(context:)` in `SwiftKLineExample/KLineSwiftUIView.swift`:

```swift
func makeUIView(context: Context) -> KLineView {
    let chart = ChartConfiguration(
        data: .deferred,
        appearance: .theme(.midnight),
        content: mode == .candlestick ? .candlestick : .timeSeries,
        indicators: .init(
            main: [.builtIn(.ma)],
            sub: [.builtIn(.vol), .builtIn(.macd)]
        ),
        features: [.liveUpdates, .gapRecovery, .indicatorPersistence],
        plugins: .default
    )
    let store = UserDefaultsIndicatorSelectionStore()
    return KLineView(chart: chart, indicatorSelectionStore: store)
}
```

- [ ] **Step 2: Keep runtime provider replacement**

Leave `updateUIView(_:,context:)` provider replacement in place:

```swift
if context.coordinator.period != period {
    let provider = BinanceDataProvider(symbol: "BTCUSDT", period: period)
    uiView.loadData(using: provider)
    uiView.invalidateIntrinsicContentSize()
    context.coordinator.period = period
}
```

This verifies the new facade and old command API work together.

- [ ] **Step 3: Verify and commit**

Run:

```bash
xcodebuild -project SwiftKLineExample.xcodeproj -scheme SwiftKLineExample -destination 'generic/platform=iOS' -derivedDataPath /tmp/swiftkline-deriveddata build CODE_SIGNING_ALLOWED=NO
```

Commit:

```bash
git add SwiftKLineExample/KLineSwiftUIView.swift
git commit -m "chore: use chart facade in example app"
```

## Task 13: Update README And Migration Guide

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace quick-start example with facade API**

Update the “基本使用” section to show:

```swift
import UIKit
import SwiftKLine

let provider = BinanceDataProvider(symbol: "BTCUSDT", period: .m1)
let chart = ChartConfiguration(
    data: .provider(provider),
    appearance: .theme(.midnight),
    content: .candlestick,
    indicators: .init(
        main: [.builtIn(.ma)],
        sub: [.builtIn(.vol), .builtIn(.macd)]
    ),
    features: [.liveUpdates, .gapRecovery, .indicatorPersistence],
    plugins: .default
)
let klineView = KLineView(chart: chart)
view.addSubview(klineView)
```

- [ ] **Step 2: Add compatibility note**

Add:

```markdown
## 兼容旧 API

旧的初始化和命令式 API 仍可用：

```swift
let view = KLineView(configuration: .themed(.midnight))
view.loadData(using: provider)
view.setChartContentStyle(.candlestick)
```

这些 API 会转发到新的 chart controller 和配置模型。新接入建议优先使用 `ChartConfiguration`。
```
```

- [ ] **Step 3: Add custom plugin example**

Add:

```markdown
## 自定义指标插件

```swift
struct MyCalculator: KLineIndicatorCalculator {
    let id = SeriesKey(indicatorID: "custom.myIndicator", name: "MY")

    func calculate(for items: [any KLineItem]) -> [Double?] {
        items.map { Optional($0.closing) }
    }
}

struct MyPlugin: KLineIndicatorPlugin {
    let id: IndicatorID = "custom.myIndicator"
    let title = "MY"
    let placement: IndicatorPlacement = .overlay
    let defaultSeriesKeys = [SeriesKey(indicatorID: "custom.myIndicator", name: "MY")]

    func makeCalculators(configuration: KLineConfiguration) -> [any KLineIndicatorCalculator] {
        [MyCalculator()]
    }

    @MainActor func makeRenderers(configuration: KLineConfiguration) -> [any Renderer] {
        [MyRenderer()]
    }
}

let registry = PluginRegistry.default
registry.register(MyPlugin())
let chart = ChartConfiguration(plugins: registry)
```
```

- [ ] **Step 4: Verify docs and commit**

Run:

```bash
rg -n "ChartConfiguration|KLineIndicatorPlugin|兼容旧 API" README.md
```

Expected: all three terms are present.

Commit:

```bash
git add README.md
git commit -m "docs: document chart facade and plugin API"
```

## Task 14: Final Audit And Cleanup

**Files:**
- Inspect all touched production, test, README, and spec/plan files.

- [ ] **Step 1: Build prompt-to-artifact checklist**

Create a local checklist in the final task notes with these rows:

```text
API 易用性 -> ChartConfiguration implemented, example uses it, README quick start uses it.
高扩展 -> Custom plugin test defines external plugin without editing Indicator enum.
易维护 -> KLineView no longer directly owns data merger, calculation engine, or global registry.
灵活特性 -> Registry isolation test passes.
兼容性 -> Old initializer/loadData/setChartContentStyle still compile and README documents them.
验证 -> iOS build gate result recorded.
```

- [ ] **Step 2: Inspect KLineView ownership**

Run:

```bash
rg -n "KLineDataMerger|IndicatorCalculationEngine|IndicatorRendererRegistry\\.shared|private var mainIndicatorTypes|private var subIndicatorTypes" Sources/SwiftKLine/View/KLineView.swift
```

Expected: no direct ownership of `KLineDataMerger`, `IndicatorCalculationEngine`, or `IndicatorRendererRegistry.shared`. Temporary compatibility fields `mainIndicatorTypes` and `subIndicatorTypes` should be removed or clearly derived from controller state.

- [ ] **Step 3: Inspect new public API symbols**

Run:

```bash
rg -n "public (struct|enum|protocol|final class) ChartConfiguration|IndicatorID|SeriesKey|KLineIndicatorPlugin|KLineIndicatorCalculator|PluginRegistry" Sources/SwiftKLine
```

Expected: all public symbols appear in the intended API/Indicator files.

- [ ] **Step 4: Run final build**

Run:

```bash
xcodebuild -project SwiftKLineExample.xcodeproj -scheme SwiftKLineExample -destination 'generic/platform=iOS' -derivedDataPath /tmp/swiftkline-deriveddata build CODE_SIGNING_ALLOWED=NO
```

Expected: BUILD SUCCEEDED, unless blocked by local signing/Xcode/cache environment. If blocked, record the exact command and error.

- [ ] **Step 5: Run final tests if an iOS test host exists**

If a test host has been added to the Xcode project during execution, run:

```bash
xcodebuild -project SwiftKLineExample.xcodeproj -scheme SwiftKLineExample -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Expected: TEST SUCCEEDED. If the project still has no iOS test host, record that SwiftPM tests cannot run because UIKit is unavailable on macOS.

- [ ] **Step 6: Final commit**

Commit any final cleanup:

```bash
git add Sources SwiftKLineExample Tests README.md
git commit -m "refactor: complete SwiftKLine architecture API overhaul"
```

Do not push. The user explicitly asked not to push code.
