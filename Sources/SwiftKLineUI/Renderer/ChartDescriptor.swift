//
//  ChartDescriptor.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2025/04/20.
//

import SwiftKLineCore
import Foundation

/// An ordered renderer-group tree with cached vertical section origins and a total intrinsic height.
///
/// Structure changes are reconciled by semantic renderer identity; ordinary data refreshes reuse this descriptor.
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
    
    /// Finds the section containing a canvas y coordinate, or nil outside the descriptor’s height.
    func indexOfGroup(at location: CGPoint) -> Int? {
        guard location.y >= 0 && location.y <= height else { return nil }
        var maxY: CGFloat = 0
        for (idx, group) in groups.enumerated() {
            maxY += group.height
            if location.y < maxY { return idx }
        }
        return nil
    }
    
    /// Returns the cached section frame in canvas coordinates; index must refer to an existing group.
    func frameOfGroup(at index: Int, rect: CGRect) -> CGRect {
        let (y, height) = layouts[index]
        return CGRect(x: rect.minX, y: y, width: rect.width, height: height)
    }
}