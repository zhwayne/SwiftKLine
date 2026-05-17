import Foundation

public typealias RendererProvider = @MainActor (
    RendererPlacement,
    ChartConfiguration
) -> [any ChartRenderer]

/// 图表插件注册表，用实例隔离外部扩展，避免回到全局单例式配置。
@MainActor public final class PluginRegistry {
    public static func makeDefault() -> PluginRegistry {
        let registry = PluginRegistry()
        registry.registerBuiltInPlugins()
        return registry
    }

    /// Creates a new default instance via `makeDefault()`.
    public static var `default`: PluginRegistry { makeDefault() }

    private var pluginsByID: [IndicatorID: any IndicatorPlugin] = [:]
    private var rendererProviders: [RendererPlacement: [RendererProvider]] = [:]

    public init() {}

    public func register(_ plugin: any IndicatorPlugin) {
        pluginsByID[plugin.id] = plugin
    }

    public func plugin(for id: IndicatorID) -> (any IndicatorPlugin)? {
        pluginsByID[id]
    }

    public func plugins(for placement: IndicatorPlacement) -> [any IndicatorPlugin] {
        pluginsByID.values.filter { $0.placement == placement }
    }

    public func registerRenderer(
        placement: RendererPlacement,
        provider: @escaping RendererProvider
    ) {
        rendererProviders[placement, default: []].append(provider)
    }

    func renderers(
        for placement: RendererPlacement,
        configuration: ChartConfiguration
    ) -> [AnyRenderer] {
        rendererProviders[placement, default: []]
            .flatMap { $0(placement, configuration) }
            .map { $0.eraseToAnyRenderer() }
    }

    func pluginRenderers(
        for id: IndicatorID,
        configuration: ChartConfiguration
    ) -> [AnyRenderer] {
        guard let plugin = pluginsByID[id] else { return [] }
        return plugin.makeRenderers(configuration: configuration).map { $0.eraseToAnyRenderer() }
    }

    private func registerBuiltInPlugins() {
        for indicator in BuiltInIndicator.allCases {
            register(BuiltInIndicatorPlugin(indicator: indicator))
        }
    }
}
