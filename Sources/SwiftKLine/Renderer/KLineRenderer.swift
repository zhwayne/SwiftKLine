//
//  KLineRenderer.swift
//  KLineDemo
//
//  Created by iya on 2024/11/1.
//

import UIKit

@MainActor public protocol KLineRenderer: AnyObject {
    typealias Context = KLineRendererContext<any KLineItem>
    associatedtype Identifier: Hashable
    
    var id: Identifier { get }
    var zIndex: Int { get }
    
    func install(to layer: CALayer)
    func uninstall(from layer: CALayer)
    func draw(in layer: CALayer, context: Context)
    
    func legend(context: Context) -> NSAttributedString?
    func dataBounds(context: Context) -> KLineMetricBounds
}

extension KLineRenderer {
    
    public var zIndex: Int {
        0
    }
    
    public func legend(context: Context) -> NSAttributedString? {
        return nil
    }
    
    public func dataBounds(context: Context) -> KLineMetricBounds {
        return .empty
    }
}

@MainActor
protocol LegendUpdatable: AnyObject {
    func updateLegend(context: KLineRendererContext<any KLineItem>)
}

final class AnyRenderer: KLineRenderer {
        
    private let _id: () -> AnyHashable
    private let _zIndex: () -> Int
    private let _installFunc: (CALayer) -> Void
    private let _uninstallFunc: (CALayer) -> Void
    private let _drawFunc: (CALayer, Context) -> Void
    private let _legendStringFunc: (Context) -> NSAttributedString?
    private let _dataBoundsFunc: (Context) -> KLineMetricBounds
    
    let base: any KLineRenderer
    
    init<R: KLineRenderer>(_ base: R) {
        self.base = base
        _id = { AnyHashable(base.id) }
        _zIndex = { base.zIndex }
        _installFunc = { base.install(to: $0) }
        _uninstallFunc = { base.uninstall(from: $0) }
        _drawFunc = {
            base.draw(in: $0, context: $1)
        }
        _legendStringFunc = { base.legend(context: $0) }
        _dataBoundsFunc = { base.dataBounds(context: $0) }
    }
    
    var id: some Hashable { _id() }
    
    var zIndex: Int { _zIndex() }
    
    func install(to layer: CALayer) {
        _installFunc(layer)
    }
    
    func uninstall(from layer: CALayer) {
        _uninstallFunc(layer)
    }
    
    func draw(in layer: CALayer, context: Context) {
        _drawFunc(layer, context)
    }
    
    func legend(context: Context) -> NSAttributedString? {
        return _legendStringFunc(context)
    }
    
    func dataBounds(context: Context) -> KLineMetricBounds {
        return _dataBoundsFunc(context)
    }
}

extension AnyRenderer: @preconcurrency Equatable {
    static func == (lhs: AnyRenderer, rhs: AnyRenderer) -> Bool {
        lhs.id == rhs.id
    }
}

extension AnyRenderer: @preconcurrency Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension KLineRenderer {
    
    func eraseToAnyRenderer() -> AnyRenderer {
        AnyRenderer(self)
    }
}

@MainActor
@resultBuilder
struct RendererBuilder {
    /// The type of individual statement expressions in the transformed function,
    /// which defaults to Component if buildExpression() is not provided.
    typealias Expression = any KLineRenderer
    
    /// The type of a partial result, which will be carried through all of the
    /// build methods.
    typealias Component = [AnyRenderer]
    
    /// Required by every result builder to build combined results from
    /// statement blocks.
    static func buildBlock(_ components: Component...) -> Component {
        return components.flatMap { $0 }
    }
    
    /// If declared, provides contextual type information for statement
    /// expressions to translate them into partial results.
    static func buildExpression(_ expression: Expression) -> Component {
        return [AnyRenderer(expression)]
    }
    
    static func buildExpression(_ expression: Expression?) -> Component {
        guard let expression else { return [] }
        return [AnyRenderer(expression)]
    }
    
    static func buildExpression<R: KLineRenderer>(_ expression: R) -> Component {
        return [AnyRenderer(expression)]
    }
    
    static func buildExpression<R: KLineRenderer>(_ expression: R?) -> Component {
        guard let expression else { return [] }
        return [AnyRenderer(expression)]
    }
    
    static func buildExpression(_ expression: AnyRenderer) -> Component {
        return [expression]
    }
    
    static func buildExpression(_ expression: [AnyRenderer]) -> Component {
        return expression
    }
    
    /// Enables support for `if` statements that do not have an `else`.
    static func buildOptional(_ component: Component?) -> Component {
        return component ?? []
    }
    
    /// With buildEither(second:), enables support for 'if-else' and 'switch'
    /// statements by folding conditional results into a single result.
    static func buildEither(first component: Component) -> Component {
        return component
    }
    
    /// With buildEither(first:), enables support for 'if-else' and 'switch'
    /// statements by folding conditional results into a single result.
    static func buildEither(second component: Component) -> Component {
        return component
    }
    
    /// Enables support for 'for..in' loops by combining the
    /// results of all iterations into a single result.
    static func buildArray(_ components: [Component]) -> Component {
        return components.flatMap { $0 }
    }
    
    /// If declared, this will be called on the partial result of an 'if
    /// #available' block to allow the result builder to erase type
    /// information.
    static func buildLimitedAvailability(_ component: Component) -> Component {
        return component
    }
}
