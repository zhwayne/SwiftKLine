//  ChartDescriptor.swift
//  SwiftKLine
//
//  Created by iya on 2025/4/20.

import Foundation

@MainActor
struct ChartDescriptor {
    
    var groups: [RendererGroup]
    let height: CGFloat
    private var layouts: [(minY: CGFloat, height: CGFloat)] = []
    
    var renderers: [AnyRenderer] {
        groups.flatMap({ $0.renderers })
    }
    
    init(@ChartBuilder _ builder: () -> [RendererGroup]) {
        groups = builder()
        height = groups.reduce(0) { $0 + $1.height }
        var y: CGFloat = 0
        layouts = groups.map { group in
            defer { y += group.height }
            return (y, group.height)
        }
    }
    
    init(groups: [RendererGroup] = []) {
        self.groups = groups
        height = groups.reduce(0) { $0 + $1.height }
        var y: CGFloat = 0
        layouts = groups.map { group in
            defer { y += group.height }
            return (y, group.height)
        }
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