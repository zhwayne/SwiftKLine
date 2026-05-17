import Foundation

public protocol IndicatorCalculator: Sendable {
    associatedtype Value: Sendable

    var id: SeriesKey { get }
    func calculate(for items: [any ChartItem]) -> [Value?]
}

@MainActor public protocol IndicatorPlugin: Sendable {
    var id: IndicatorID { get }
    var title: String { get }
    var placement: IndicatorPlacement { get }
    var defaultSeriesKeys: [SeriesKey] { get }

    func makeCalculators(configuration: ChartConfiguration) -> [any IndicatorCalculator]
    @MainActor func makeRenderers(configuration: ChartConfiguration) -> [any ChartRenderer]
}

struct AnyIndicatorCalculator: Sendable {
    let id: SeriesKey
    private let calculateValues: @Sendable ([any ChartItem]) -> AnyIndicatorSeries

    init<C: IndicatorCalculator>(_ calculator: C) {
        id = calculator.id
        calculateValues = { items in
            AnyIndicatorSeries(key: calculator.id, values: ContiguousArray(calculator.calculate(for: items)))
        }
    }

    func calculateStore(items: [any ChartItem]) -> IndicatorSeriesStore {
        var store = IndicatorSeriesStore()
        store.setSeries(calculateValues(items), for: id)
        return store
    }
}
