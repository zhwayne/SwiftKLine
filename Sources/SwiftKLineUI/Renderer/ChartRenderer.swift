//
//  ChartRenderer.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2024/11/01.
//

import SwiftKLineCore
import UIKit

    /// The coherent snapshot and current section geometry supplied for each rendering operation.
@MainActor public protocol ChartRenderer: AnyObject {
    typealias Context = ChartContext
    /// A hashable semantic identity used to reconcile renderer instances across descriptor rebuilds.
    associatedtype Identifier: Hashable
    
    /// The complete rendering identity, including parameters that distinguish incompatible renderer instances.
    var id: Identifier { get }
    /// The ordering priority within a group; ties retain declaration order and the default is zero.
    var zIndex: Int { get }
    
    /// Attaches owned layers or views to the supplied canvas; subsequent draws should reuse those objects.
    func install(to layer: CALayer)
    /// Detaches every object installed by this renderer, allowing the chart to remove the renderer cleanly.
    func uninstall(from layer: CALayer)
    /// Updates only the visible content using the current snapshot and group viewport.
    func draw(in layer: CALayer, context: Context)
    
    /// Returns an attributed legend for the current selected or latest visible candle; nil opts out.
    func legend(context: Context) -> NSAttributedString?
    /// Returns this renderer’s visible value range; empty bounds opt out of value-axis scaling.
    func dataBounds(context: Context) -> ValueBounds
}

extension ChartRenderer {
    
    /// Uses the default group ordering priority of zero.
    public var zIndex: Int {
        0
    }
    
    /// Opts out of legend content unless the renderer overrides this implementation.
    public func legend(context: Context) -> NSAttributedString? {
        return nil
    }
    
    /// Opts out of axis scaling unless the renderer overrides this implementation.
    public func dataBounds(context: Context) -> ValueBounds {
        return .empty
    }
}

/// Allows a renderer to update an embedded legend without redrawing price paths.
@MainActor
protocol LegendUpdatable: AnyObject {
    /// Refreshes embedded legend content using the selected index and current group geometry.
    func updateLegend(context: ChartContext)
}

/// Existential forwarding keeps one renderer reference rather than allocating a closure for each method.
@MainActor
final class AnyRenderer: ChartRenderer {
    let base: any ChartRenderer
    /// The complete rendering identity, including parameters that distinguish incompatible renderer instances.
    var id: AnyHashable { AnyHashable(base.id) }
    /// The ordering priority within a group; ties retain declaration order and the default is zero.
    var zIndex: Int { base.zIndex }

    init(_ base: any ChartRenderer) { self.base = base }
    /// Attaches owned layers or views to the supplied canvas; subsequent draws should reuse those objects.
    func install(to layer: CALayer) { base.install(to: layer) }
    /// Detaches every object installed by this renderer, allowing the chart to remove the renderer cleanly.
    func uninstall(from layer: CALayer) { base.uninstall(from: layer) }
    /// Updates only the visible content using the current snapshot and group viewport.
    func draw(in layer: CALayer, context: ChartContext) { base.draw(in: layer, context: context) }
    /// Returns an attributed legend for the current selected or latest visible candle; nil opts out.
    func legend(context: ChartContext) -> NSAttributedString? { base.legend(context: context) }
    /// Returns this renderer’s visible value range; empty bounds opt out of value-axis scaling.
    func dataBounds(context: ChartContext) -> ValueBounds { base.dataBounds(context: context) }
}

extension ChartRenderer {
    
    func eraseToAnyRenderer() -> AnyRenderer {
        AnyRenderer(self)
    }
}


