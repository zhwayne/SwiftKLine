//
//  DebugDrawReporter.swift
//  SwiftKLine
//
//  Created by zhwayne on 2026/4/27.
//

#if DEBUG
import QuartzCore
import Foundation

struct DebugDrawReporter {
    private var frameCount: Int = 0
    private var lastReportTime: CFTimeInterval = CACurrentMediaTime()

    mutating func report(
        drawStartTime: CFTimeInterval,
        legendCost: CFTimeInterval,
        boundsCost: CFTimeInterval,
        rendererCost: CFTimeInterval,
        mode: RedrawMode
    ) {
        frameCount += 1
        let now = CACurrentMediaTime()
        guard now - lastReportTime >= 1 else { return }
        let totalCost = now - drawStartTime
        print(
            "[SwiftKLine][Perf] fps=\(frameCount)/s mode=\(mode) " +
            "total=\(String(format: "%.4f", totalCost))s " +
            "legend=\(String(format: "%.4f", legendCost))s " +
            "bounds=\(String(format: "%.4f", boundsCost))s " +
            "render=\(String(format: "%.4f", rendererCost))s"
        )
        frameCount = 0
        lastReportTime = now
    }
}
#endif
