//
//  ChartBuilder.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/05/17.
//

import SwiftKLineCore
/// Flattens declarative chart groups while supporting conditions, loops, and availability branches.
@resultBuilder
struct ChartBuilder {

    static func buildBlock(_ components: [RendererGroup]...) -> [RendererGroup] {
        components.flatMap { $0 }
    }

    static func buildExpression(_ group: RendererGroup) -> [RendererGroup] {
        [group]
    }

    static func buildExpression(_ groups: [RendererGroup]) -> [RendererGroup] {
        groups
    }

    static func buildOptional(_ component: [RendererGroup]?) -> [RendererGroup] {
        component ?? []
    }

    static func buildEither(first component: [RendererGroup]) -> [RendererGroup] {
        component
    }

    static func buildEither(second component: [RendererGroup]) -> [RendererGroup] {
        component
    }

    static func buildArray(_ components: [[RendererGroup]]) -> [RendererGroup] {
        components.flatMap { $0 }
    }

    static func buildLimitedAvailability(_ component: [RendererGroup]) -> [RendererGroup] {
        component
    }
}