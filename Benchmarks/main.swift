//
//  main.swift
//  SwiftKLineBenchmark
//
//  Created by zhwayne on 2026/10/21.
//

import Foundation
import SwiftKLineCore

// Release-only microbenchmark. Baselines reproduce the previous per-window implementations.
let count = Int(CommandLine.arguments.dropFirst().first ?? "20000") ?? 20_000
let period = 200
let items: [any ChartItem] = (0..<max(period, count)).map {
    let price = 100 + sin(Double($0) * 0.1) * 10
    return Candle(timestamp: $0 * 60, open: price, high: price + 1, low: price - 1, close: price)
}

func measure(_ name: String, _ run: () -> Double) {
    var times: [Double] = []
    var checksum = 0.0
    for _ in 0..<5 {
        let start = ProcessInfo.processInfo.systemUptime
        checksum += run()
        times.append((ProcessInfo.processInfo.systemUptime - start) * 1000)
    }
    print(String(format: "%@: median %.3f ms; checksum %.6f", name, times.sorted()[2], checksum))
}

print("Candles: \(items.count), period: \(period), 5 iterations, median wall-clock time")
measure("WMA window baseline") {
    var values = [Double?](repeating: nil, count: items.count)
    let denominator = Double(period * (period + 1) / 2)
    for i in (period - 1)..<items.count {
        var weighted = 0.0
        for offset in 0..<period { weighted += items[i - period + 1 + offset].close * Double(offset + 1) }
        values[i] = weighted / denominator
    }
    return values.last!!
}
measure("WMA rolling") { WMACalculator(period: period).calculate(for: items).last!! }
measure("BOLL window baseline") {
    var values = [BOLLIndicatorValue?](repeating: nil, count: items.count)
    for i in (period - 1)..<items.count {
        let closes = items[(i - period + 1)...i].map(\.close)
        let mean = closes.reduce(0, +) / Double(period)
        let deviation = sqrt(closes.reduce(0) { $0 + pow($1 - mean, 2) } / Double(period)) * 2
        values[i] = BOLLIndicatorValue(middle: mean, upper: mean + deviation, lower: mean - deviation)
    }
    return values.last!!.upper
}
measure("BOLL rolling") { BOLLCalculator(period: period).calculate(for: items).last!!.upper }
let calculator = WMACalculator(period: period)
let previous = calculator.calculate(for: items)
measure("WMA tail update including array copy") {
    var values = previous
    calculator.update(for: items, values: &values, from: items.count - 1)
    return values.last!!
}
