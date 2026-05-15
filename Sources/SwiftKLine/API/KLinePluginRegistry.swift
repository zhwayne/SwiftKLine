import Foundation

public typealias RendererProvider = @MainActor (
    RendererPlacement,
    KLineConfiguration
) -> [any KLineRenderer]

/// 图表插件注册表，用实例隔离外部扩展，避免回到全局单例式配置。
@MainActor public final class PluginRegistry {
    public static func makeDefault() -> PluginRegistry {
        let registry = PluginRegistry()
        registry.registerBuiltInPlugins()
        return registry
    }

    /// Deprecated: use `makeDefault()` instead of the singleton.
    @available(*, deprecated, message: "Use PluginRegistry.makeDefault() to create a new instance.")
    public static let `default`: PluginRegistry = makeDefault()

    private var pluginsByID: [IndicatorID: any KLineIndicatorPlugin] = [:]
    private var rendererProviders: [RendererPlacement: [RendererProvider]] = [:]

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
        provider: @escaping RendererProvider
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
        for indicator in KLineIndicator.allCases {
            register(BuiltInIndicatorPlugin(indicator: indicator))
        }
    }
}
