//
//  PluginRenderer.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/10/21.
//

import UIKit
import SwiftKLineCore

/// Routes every renderer operation through its owning plugin's calculation snapshot.
@MainActor
final class PluginRenderer: ChartRenderer, LegendUpdatable {
    struct ID: Hashable { let plugin: String; let local: String; let object: ObjectIdentifier }
    let id: ID
    let base: any ChartRenderer
    var zIndex: Int { base.zIndex }
    init(plugin: String, local: String, renderer: any ChartRenderer) {
        id = ID(plugin: plugin, local: local, object: ObjectIdentifier(renderer))
        base = renderer
    }
    func install(to layer: CALayer) { base.install(to: layer) }
    func uninstall(from layer: CALayer) { base.uninstall(from: layer) }
    func draw(in layer: CALayer, context: ChartContext) { base.draw(in: layer, context: context.scoped(to: id.plugin)) }
    func dataBounds(context: ChartContext) -> ValueBounds { base.dataBounds(context: context.scoped(to: id.plugin)) }
    func legend(context: ChartContext) -> NSAttributedString? { base.legend(context: context.scoped(to: id.plugin)) }
    func updateLegend(context: ChartContext) {
        (base as? LegendUpdatable)?.updateLegend(context: context.scoped(to: id.plugin))
    }
}
