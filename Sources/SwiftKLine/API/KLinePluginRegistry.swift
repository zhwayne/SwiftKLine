import Foundation

public typealias KLineRendererProvider = @MainActor (
    KLineRendererPlacement,
    KLineConfiguration
) -> [any KLineRenderer]

/// 图表插件注册表，用实例隔离外部扩展，避免回到全局单例式配置。
@MainActor public final class KLinePluginRegistry {
    public static let `default`: KLinePluginRegistry = {
        let registry = KLinePluginRegistry()
        registry.registerBuiltInPlugins()
        return registry
    }()

    private var pluginsByID: [KLineIndicatorID: any KLineIndicatorPlugin] = [:]
    private var rendererProviders: [KLineRendererPlacement: [KLineRendererProvider]] = [:]

    public init() {}

    public func register(_ plugin: any KLineIndicatorPlugin) {
        pluginsByID[plugin.id] = plugin
    }

    public func plugin(for id: KLineIndicatorID) -> (any KLineIndicatorPlugin)? {
        pluginsByID[id]
    }

    public func plugins(for placement: KLineIndicatorPlacement) -> [any KLineIndicatorPlugin] {
        pluginsByID.values.filter { $0.placement == placement }
    }

    public func registerRenderer(
        placement: KLineRendererPlacement,
        provider: @escaping KLineRendererProvider
    ) {
        rendererProviders[placement, default: []].append(provider)
    }

    func renderers(
        for placement: KLineRendererPlacement,
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
