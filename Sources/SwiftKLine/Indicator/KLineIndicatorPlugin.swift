import Foundation

public protocol KLineIndicatorCalculator: Sendable {
    associatedtype Value: Sendable

    var id: KLineSeriesKey { get }
    func calculate(for items: [any KLineItem]) -> [Value?]
}

@MainActor public protocol KLineIndicatorPlugin: Sendable {
    var id: KLineIndicatorID { get }
    var title: String { get }
    var placement: KLineIndicatorPlacement { get }
    var defaultSeriesKeys: [KLineSeriesKey] { get }

    func makeCalculators(configuration: KLineConfiguration) -> [any KLineIndicatorCalculator]
    @MainActor func makeRenderers(configuration: KLineConfiguration) -> [any KLineRenderer]
}

struct AnyIndicatorCalculator: Sendable {
    let id: KLineSeriesKey
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
