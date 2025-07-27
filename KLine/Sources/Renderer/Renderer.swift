//
//  Renderer.swift
//  KLineDemo
//
//  Created by iya on 2024/11/1.
//

import UIKit

@MainActor public protocol Renderer: AnyObject {
    typealias Context = RendererContext<any KLineItem>
    associatedtype Identifier: Hashable
    
    var id: Identifier { get }
    
    func install(to layer: CALayer)
    func uninstall(from layer: CALayer)
    func draw(in layer: CALayer, context: Context)
    
    func legend(at index: Int, context: Context) -> NSAttributedString?
    func dataBounds(context: Context) -> MetricBounds
}

extension Renderer {
    
    public func legend(at index: Int, context: Context) -> NSAttributedString? {
        return nil
    }
    
    public func dataBounds(context: Context) -> MetricBounds {
        return .empty
    }
}

final class AnyRenderer: Renderer {
        
    private let _id: () -> AnyHashable
    private let _installFunc: (CALayer) -> Void
    private let _uninstallFunc: (CALayer) -> Void
    private let _drawFunc: (CALayer, Context) -> Void
    private let _legendStringFunc: (Int, Context) -> NSAttributedString?
    private let _dataBoundsFunc: (Context) -> MetricBounds
    
    let base: any Renderer
    
    init<R: Renderer>(_ base: R) {
        self.base = base
        _id = { AnyHashable(base.id) }
        _installFunc = { base.install(to: $0) }
        _uninstallFunc = { base.uninstall(from: $0) }
        _drawFunc = {
            base.draw(in: $0, context: $1)
        }
        _legendStringFunc = { base.legend(at: $0, context: $1) }
        _dataBoundsFunc = { base.dataBounds(context: $0) }
    }
    
    var id: some Hashable { _id() }
    
    func install(to layer: CALayer) {
        _installFunc(layer)
    }
    
    func uninstall(from layer: CALayer) {
        _uninstallFunc(layer)
    }
    
    func draw(in layer: CALayer, context: Context) {
        _drawFunc(layer, context)
    }
    
    func legend(at index: Int, context: Context) -> NSAttributedString? {
        return _legendStringFunc(index, context)
    }
    
    func dataBounds(context: Context) -> MetricBounds {
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

extension Renderer {
    
    func eraseToAnyRenderer() -> AnyRenderer {
        AnyRenderer(self)
    }
}

@MainActor
@resultBuilder
struct RendererBuilder {
    /// The type of individual statement expressions in the transformed function,
    /// which defaults to Component if buildExpression() is not provided.
    typealias Expression = any Renderer
    
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
