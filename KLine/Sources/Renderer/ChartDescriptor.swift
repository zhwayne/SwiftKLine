//
//  ChartDescriptor.swift
//  KLine
//
//  Created by iya on 2025/4/20.
//

import Foundation

@MainActor
struct ChartDescriptor {
    
    let groups: [RendererGroup]
    let height: CGFloat
    private var layouts: [(minY: CGFloat, height: CGFloat)] = []
    
    var renderers: [AnyRenderer] {
        groups.flatMap({ $0.renderers })
    }
    
    typealias Builder = ArrayBuilder
    
    init(@Builder _ builder: () -> [RendererGroup]) {
        groups = builder()
        height = groups.reduce(0) { $0 + $1.height }
        var y: CGFloat = 0
        layouts = groups.map { group in
            defer { y += group.height }
            return (y, group.height)
        }
    }
    
    init() {
        groups = []
        height = 0
    }
}

extension ChartDescriptor {
    
    func indexOfGroup(at location: CGPoint) -> Int? {
        guard location.y >= 0 && location.y <= height else { return nil }
        var maxY: CGFloat = 0
        for (idx, group) in groups.enumerated() {
            maxY += group.height
            if location.y < maxY { return idx }
        }
        return nil
    }
    
    func frameOfGroup(at index: Int, rect: CGRect) -> CGRect {
        let (y, height) = layouts[index]
        return CGRect(x: rect.minX, y: y, width: rect.width, height: height)
    }
}
