import Foundation

@MainActor
struct RenderPipeline {
    private let descriptorFactory = DescriptorFactory()
    private let registry: PluginRegistry

    init(registry: PluginRegistry) {
        self.registry = registry
    }

    func makeDescriptor(
        contentStyle: ChartType,
        mainIndicatorIDs: [IndicatorID],
        subIndicatorIDs: [IndicatorID],
        customRenderers: [AnyRenderer],
        configuration: KLineConfiguration,
        layoutMetrics: LayoutMetrics
    ) -> ChartDescriptor {
        descriptorFactory.makeDescriptor(
            contentStyle: contentStyle,
            mainIndicatorIDs: mainIndicatorIDs,
            subIndicatorIDs: subIndicatorIDs,
            customRenderers: customRenderers,
            configuration: configuration,
            layoutMetrics: layoutMetrics,
            registry: registry
        )
    }

    func makeDescriptor(
        contentStyle: ChartType,
        mainIndicators: [KLineIndicator],
        subIndicators: [KLineIndicator],
        customRenderers: [AnyRenderer],
        configuration: KLineConfiguration,
        layoutMetrics: LayoutMetrics
    ) -> ChartDescriptor {
        makeDescriptor(
            contentStyle: contentStyle,
            mainIndicatorIDs: mainIndicators.map(\.kLineID),
            subIndicatorIDs: subIndicators.map(\.kLineID),
            customRenderers: customRenderers,
            configuration: configuration,
            layoutMetrics: layoutMetrics
        )
    }
}
