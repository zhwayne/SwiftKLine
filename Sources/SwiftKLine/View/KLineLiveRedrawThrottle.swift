//
//  KLineLiveRedrawThrottle.swift
//  SwiftKLine
//
//  Created by zhwayne on 2026/4/27.
//

import QuartzCore

struct KLineLiveRedrawThrottle {
    private let interval: CFTimeInterval
    private var lastRedrawTime: CFTimeInterval = 0

    init(interval: CFTimeInterval = 0.2) {
        self.interval = interval
    }

    mutating func reset() {
        lastRedrawTime = 0
    }

    mutating func shouldRedraw(now: CFTimeInterval = CACurrentMediaTime()) -> Bool {
        guard now - lastRedrawTime >= interval else { return false }
        lastRedrawTime = now
        return true
    }
}
