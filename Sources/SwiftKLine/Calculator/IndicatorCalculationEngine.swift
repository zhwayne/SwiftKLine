import Foundation

@MainActor
struct IndicatorCalculationEngine {
    private let registry: KLinePluginRegistry

    init(registry: KLinePluginRegistry = .default) {
        self.registry = registry
    }

    func calculate(
        items: [any KLineItem],
        indicatorIDs: [KLineIndicatorID],
        configuration: KLineConfiguration
    ) async -> IndicatorSeriesStore {
        let calculators = indicatorIDs.flatMap { id -> [any KLineIndicatorCalculator] in
            if let indicator = KLineIndicator(kLineID: id) {
                return BuiltInIndicatorPlugin(indicator: indicator).makeCalculators(configuration: configuration)
            }
            return registry.plugin(for: id)?.makeCalculators(configuration: configuration) ?? []
        }
        let erased = calculators.map { $0.eraseToAnyIndicatorCalculator() }
        return await erased.calculate(items: items)
    }

    func calculate(
        items: [any KLineItem],
        mainIndicators: [KLineIndicator],
        subIndicators: [KLineIndicator],
        configuration: KLineConfiguration
    ) async -> IndicatorSeriesStore {
        await calculate(
            items: items,
            indicatorIDs: (mainIndicators + subIndicators).map(\.kLineID),
            configuration: configuration
        )
    }
}
