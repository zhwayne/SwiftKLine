//  RendererBuilder.swift
//  SwiftKLine

import UIKit

@MainActor
@resultBuilder
struct RendererBuilder {

    static func buildBlock(_ components: [AnyRenderer]...) -> [AnyRenderer] {
        components.flatMap { $0 }
    }

    static func buildExpression<R: ChartRenderer>(_ renderer: R) -> [AnyRenderer] {
        [renderer.eraseToAnyRenderer()]
    }

    static func buildExpression<R: ChartRenderer>(_ renderer: R?) -> [AnyRenderer] {
        renderer.map { [$0.eraseToAnyRenderer()] } ?? []
    }

    static func buildExpression(_ renderer: any ChartRenderer) -> [AnyRenderer] {
        [renderer.eraseToAnyRenderer()]
    }

    static func buildExpression(_ renderers: [AnyRenderer]) -> [AnyRenderer] {
        renderers
    }

    static func buildOptional(_ component: [AnyRenderer]?) -> [AnyRenderer] {
        component ?? []
    }

    static func buildEither(first component: [AnyRenderer]) -> [AnyRenderer] {
        component
    }

    static func buildEither(second component: [AnyRenderer]) -> [AnyRenderer] {
        component
    }

    static func buildArray(_ components: [[AnyRenderer]]) -> [AnyRenderer] {
        components.flatMap { $0 }
    }

    static func buildLimitedAvailability(_ component: [AnyRenderer]) -> [AnyRenderer] {
        component
    }
}