//
//  PluginRegistry.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/05/17.
//

import SwiftKLineCore
import Foundation

/// A main-actor factory creating additional renderers for a registration hook and visual configuration.
public typealias RendererProvider = @MainActor (
    RendererPlacement,
    ChartConfiguration
) -> [any ChartRenderer]

    /// Creates an independent registry containing every built-in indicator plugin.
@MainActor public final class PluginRegistry {
    public static func makeDefault() -> PluginRegistry {
        let registry = PluginRegistry()
        registry.registerBuiltInPlugins()
        return registry
    }

    /// Returns a new default registry on each access, allowing independent chart customization.
    public static var `default`: PluginRegistry { makeDefault() }

    private var pluginOrder: [IndicatorID] = []
    private var pluginsByID: [IndicatorID: any IndicatorPlugin] = [:]
    private var rendererProviders: [RendererPlacement: [RendererProvider]] = [:]

    /// Creates an empty registry with no built-in plugins or extra renderers.
    public init() {}

    /// Registers or replaces an indicator plugin while retaining its registration position.
    ///
    /// - Parameter plugin: The complete calculator and renderer plugin.
    /// - Returns: The previously registered plugin for the same ID, if any.
    @discardableResult
    public func register(_ plugin: any IndicatorPlugin) -> (any IndicatorPlugin)? {
        let old = pluginsByID[plugin.id]
        if old == nil { pluginOrder.append(plugin.id) }
        pluginsByID[plugin.id] = plugin
        return old
    }

    /// Returns the plugin registered for an exact ID, or nil.
    public func plugin(for id: IndicatorID) -> (any IndicatorPlugin)? {
        pluginsByID[id]
    }

    /// Returns exact-placement matches in registration order; callers expand overlay eligibility separately.
    public func plugins(for placement: IndicatorPlacement) -> [any IndicatorPlugin] {
        pluginOrder.compactMap { pluginsByID[$0] }.filter { $0.placement == placement }
    }

    /// Appends an additional renderer factory at a placement hook.
    ///
    /// Factories run when descriptor structure is assembled, not for every data tick.
    /// - Parameters:
    ///   - placement: Hook at which the additional renderers are attached.
    ///   - provider: Main-actor factory retained by this registry.
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
