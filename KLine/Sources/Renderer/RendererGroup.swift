//
//  RendererGroup.swift
//  KLine
//
//  Created by iya on 2025/4/20.
//

import Foundation

@MainActor
struct RendererGroup {
    
    let height: CGFloat
    let padding: (top: CGFloat, bottom: CGFloat)
    let renderers: [AnyRenderer]
    
    typealias Builder = RendererBuilder
    
    init(
        height: CGFloat,
        padding: (CGFloat, CGFloat) = (0, 2),
        @Builder renderers: () -> [AnyRenderer]
    ) {
        self.height = height
        self.padding = padding
        self.renderers = renderers()
    }
}

extension RendererGroup {
    
//    func legend(at index: Int, context: Renderer.Context) -> (NSAttributedString, CGRect) {
//        let legendString = NSMutableAttributedString()
//        for renderer in renderers {
//            if let text = renderer.legendString(at: index, context: context) {
//                legendString.append(text)
//            }
//        }
//        let groupFrame = context.groupFrame
//        var rect = CGRect(
//            x: 16,
//            y: 12 + padding.top + groupFrame.minY,
//            width: context.layout.containerSize.width - 32,
//            height: 0
//        )
//        let boundingRect = legendString.boundingRect(
//            with: rect.size,
//            options: [.usesLineFragmentOrigin, .usesFontLeading],
//            context: nil
//        )
//        return (legendString, boundingRect)
//    }
//    
//    func viewPort(at index: Int, context: Renderer.Context) -> CGRect {
//        
//    }
}

//
//@resultBuilder
//struct RendererGroupBuilder {
//    
//    static func buildBlock(_ components: RendererGroup...) -> [RendererGroup] {
//        return components
//    }
//    
//    static func buildBlock(_ components: [RendererGroup]...) -> [RendererGroup] {
//        return components.flatMap { $0 }
//    }
//    
//    /// Add support for loops.
//    static func buildArray(_ components: [[RendererGroup]]) -> [RendererGroup] {
//        return components.flatMap { $0 }
//    }
//    
//    /// Add support for optionals.
//    static func buildOptional(_ components: [RendererGroup]?) -> [RendererGroup] {
//        components ?? []
//    }
//    
//    /// Add support for both single and collections of constraints.
//    static func buildExpression(_ expression: RendererGroup) -> [RendererGroup] {
//        return [expression]
//    }
//    
//    static func buildExpression(_ expressions: [RendererGroup]) -> [RendererGroup] {
//        return expressions
//    }
//    
//    /// Add support for if statements.
//    static func buildEither(first components: [RendererGroup]) -> [RendererGroup] {
//        return components
//    }
//    
//    static func buildEither(second components: [RendererGroup]) -> [RendererGroup] {
//        return components
//    }
//    
//    /// Add support for #availability checks.
//    static func buildLimitedAvailability(_ component: [RendererGroup]) -> [RendererGroup] {
//        return component
//    }
//}
