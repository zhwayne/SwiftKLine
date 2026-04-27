//
//  CGPath++.swift
//  SwiftKLine
//
//  Created by iya on 2025/4/20.
//

import CoreGraphics

extension Collection where Element == CGPoint {
    
    var cgPath: CGPath {
        let path = CGMutablePath()
        guard count > 1 else { return path }
        path.move(to: first!)
        dropFirst().forEach { path.addLine(to: $0) }
        return path
    }
}
