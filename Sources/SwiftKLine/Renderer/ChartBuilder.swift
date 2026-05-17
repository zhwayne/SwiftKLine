//  ChartBuilder.swift
//  SwiftKLine

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