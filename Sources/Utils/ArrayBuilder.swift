//
//  ArrayBuilder.swift
//  KLine
//
//  Created by iya on 2025/4/22.
//

import Foundation

@resultBuilder
struct ArrayBuilder {

    static func buildBlock<T>(_ components: T...) -> [T] {
        return components
    }

    static func buildBlock<T>(_ components: [T]...) -> [T] {
        return components.flatMap { $0 }
    }

    /// Add support for loops.
    static func buildArray<T>(_ components: [[T]]) -> [T] {
        return components.flatMap { $0 }
    }

    /// Add support for optionals.
    static func buildOptional<T>(_ components: [T]?) -> [T] {
        components ?? []
    }

    /// Add support for both single and collections of constraints.
    static func buildExpression<T>(_ expression: T) -> [T] {
        return [expression]
    }

    static func buildExpression<T>(_ expressions: [T]) -> [T] {
        return expressions
    }

    /// Add support for if statements.
    static func buildEither<T>(first components: [T]) -> [T] {
        return components
    }

    static func buildEither<T>(second components: [T]) -> [T] {
        return components
    }

    /// Add support for #availability checks.
    static func buildLimitedAvailability<T>(_ component: [T]) -> [T] {
        return component
    }
}
