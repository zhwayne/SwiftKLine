//
//  ChartRenderer.swift
//  KLineDemo
//
//  Created by iya on 2024/11/1.
//

import UIKit

@MainActor public protocol ChartRenderer: AnyObject {
    typealias Context = ChartContext
    associatedtype Identifier: Hashable
    
    var id: Identifier { get }
    var zIndex: Int { get }
    
    func install(to layer: CALayer)
    func uninstall(from layer: CALayer)
    func draw(in layer: CALayer, context: Context)
    
    func legend(context: Context) -> NSAttributedString?
    func dataBounds(context: Context) -> ValueBounds
}

extension ChartRenderer {
    
    public var zIndex: Int {
        0
    }
    
    public func legend(context: Context) -> NSAttributedString? {
        return nil
    }
    
    public func dataBounds(context: Context) -> ValueBounds {
        return .empty
    }
}

@MainActor
protocol LegendUpdatable: AnyObject {
    func updateLegend(context: ChartContext)
}

final class AnyRenderer: ChartRenderer {
        
    private let _id: () -> AnyHashable
    private let _zIndex: () -> Int
    private let _installFunc: (CALayer) -> Void
    private let _uninstallFunc: (CALayer) -> Void
    private let _drawFunc: (CALayer, Context) -> Void
    private let _legendStringFunc: (Context) -> NSAttributedString?
    private let _dataBoundsFunc: (Context) -> ValueBounds
    
    let base: any ChartRenderer
    
    init<R: ChartRenderer>(_ base: R) {
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
    
    func dataBounds(context: Context) -> ValueBounds {
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

extension ChartRenderer {
    
    func eraseToAnyRenderer() -> AnyRenderer {
        AnyRenderer(self)
    }
}


