import UIKit

/// 渲染器上下文
/// 包含渲染K线图所需的所有上下文信息
@MainActor public final class ChartContext {
    let indicatorSeriesStore: IndicatorSeriesStore
    public let items: [any ChartItem]
    public let configuration: ChartConfiguration
    public let candleDimensions: CandleDimensions
    public let visibleRange: Range<Int>
    public let layout: ChartLayout
    public let location: CGPoint?
    public let currentIndex: Int
    public internal(set) var groupFrame: CGRect = .zero
    public internal(set) var viewPort: CGRect = .zero
    public internal(set) var legendFrame: CGRect = .zero
    public internal(set) var legendText: NSAttributedString?

    init(
        indicatorSeriesStore: IndicatorSeriesStore,
        items: [any ChartItem],
        configuration: ChartConfiguration,
        candleDimensions: CandleDimensions,
        visibleRange: Range<Int>,
        layout: ChartLayout,
        location: CGPoint?,
        selectedIndex: Int?
    ) {
        self.indicatorSeriesStore = indicatorSeriesStore
        self.items = items
        self.configuration = configuration
        self.candleDimensions = candleDimensions
        self.visibleRange = visibleRange
        self.layout = layout
        self.location = location
        self.currentIndex = selectedIndex ?? visibleRange.upperBound - 1
    }
}

/// 渲染器上下文的扩展方法
extension ChartContext {

    public var visibleItems: ArraySlice<any ChartItem> {
        guard !items.isEmpty,
              visibleRange.lowerBound >= 0,
              visibleRange.upperBound <= items.count else {
            return []
        }
        return items[visibleRange]
    }

    /// 通用可见区间切片工具。
    /// 仅负责边界校验和切片，不关心具体指标类型。
    private func visibleValues<T>(from values: ContiguousArray<T>?) -> ArraySlice<T>? {
        guard let values else { return nil }
        guard !values.isEmpty,
              visibleRange.lowerBound >= 0,
              visibleRange.upperBound <= values.count else {
            return nil
        }
        return values[visibleRange]
    }

    public func values<Value>(
        for key: SeriesKey,
        as type: Value.Type
    ) -> ContiguousArray<Value?>? {
        indicatorSeriesStore.values(for: key, as: type)
    }
}

extension ChartContext {
    func scalarValues(for key: SeriesKey) -> ContiguousArray<Double?>? {
        indicatorSeriesStore.values(for: key, as: Double.self)
    }

    func visibleScalarValues(for key: SeriesKey) -> ArraySlice<Double?>? {
        visibleValues(from: scalarValues(for: key))
    }

    func bollValues(for key: SeriesKey = .boll(period: 20, k: 2.0)) -> ContiguousArray<BOLLIndicatorValue?>? {
        indicatorSeriesStore.values(for: key, as: BOLLIndicatorValue.self)
    }

    func visibleBollValues(for key: SeriesKey = .boll(period: 20, k: 2.0)) -> ArraySlice<BOLLIndicatorValue?>? {
        visibleValues(from: bollValues(for: key))
    }

    func macdValues(for key: SeriesKey = .macd(shortPeriod: 12, longPeriod: 26, signalPeriod: 9)) -> ContiguousArray<MACDIndicatorValue?>? {
        indicatorSeriesStore.values(for: key, as: MACDIndicatorValue.self)
    }

    func visibleMacdValues(for key: SeriesKey = .macd(shortPeriod: 12, longPeriod: 26, signalPeriod: 9)) -> ArraySlice<MACDIndicatorValue?>? {
        visibleValues(from: macdValues(for: key))
    }
}
